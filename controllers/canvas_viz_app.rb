require 'sinatra'
require 'sinatra/base'
require 'config_env'
require 'rack/ssl-enforcer'
require 'httparty'
require 'slim'
require 'slim/include'
require 'rack-flash'
require 'chartkick'
require 'ap'
require 'json'
require 'tilt/kramdown'

configure :development, :test do
  absolute_path = File.absolute_path './config/config_env.rb'
  ConfigEnv.path_to_config(absolute_path)
end

LOGGED_OUT_MSG = 'You were inactive for 3 hours. You need to sign in again.'
LOGOUT = "/logout?sym=error&msg=#{LOGGED_OUT_MSG}"

# Visualizations for Canvas LMS Classes
class CanvasVisualizationApp < Sinatra::Base
  enable :logging
  use Rack::MethodOverride

  set :views, File.expand_path('../../views', __FILE__)
  set :public_folder, File.expand_path('../../public', __FILE__)

  configure :development, :test do
    set :api_root, 'http://localhost:9292/api/v1'
  end

  configure :production do
    use Rack::SslEnforcer
    set :session_secret, ENV['MSG_KEY']
    set :api_root, 'https://canvas-viz-api.herokuapp.com/api/v1'
  end

  configure do
    use Rack::Session::Pool, secret: settings.session_secret
    use Rack::Flash, sweep: true
  end

  register do
    def auth(*types)
      condition do
        if (types.include? :email_token) && !@email_token
          flash[:error] = 'You must be logged in to view that page'
          redirect '/'
        elsif (types.include? :regular_token) && !@regular_token
          flash[:error] = 'You must enter a password to view that page'
          redirect '/welcome'
        end; end
    end
  end

  before do
    @email_token = session[:email_token]
    @email_address = session[:email]
    @regular_token = session[:regular_token]
  end

  def invalid_token?(result)
    result = CheckResult.new(result).call
    return unless result
    flash[:error] = result
    redirect '/tokens'
  end

  get '/' do
    google_url = GetOAuthClientIDFromAPI.new.call
    slim :index, locals: { google_url: google_url }
  end

  get '/oauth2callback_gmail/?' do
    email_from_api = GetEmailFromAPI.new(params['code']).call
    session[:email_token] = email_from_api['encrypted_email']
    session[:email] = email_from_api['email']
    redirect '/welcome'
  end

  get '/logout/?' do
    session[:email_token] = nil
    session[:email] = nil
    session[:regular_token] = nil
    sym = params['sym'] ? params['sym'].to_sym : :notice
    msg = params['msg'] ? params['msg'] : 'Logged out'
    flash[sym] = msg
    redirect '/'
  end

  get '/welcome/?', auth: [:email_token] do
    slim :welcome
  end

  post '/retrieve', auth: [:email_token] do
    password = params['password']
    result = VerifyPassword.new(
      settings.api_root, @email_token, password).call
    if result.code == 401
      redirect LOGOUT
    elsif result.body == 'no password found'
      flash[:error] = 'You\'re yet to save a password.'
      redirect '/welcome'
    elsif result.body == 'wrong password'
      flash[:error] = 'Wrong Password'
      redirect '/welcome'
    end
    session[:regular_token] = result.body
    redirect '/tokens'
  end

  post '/new_teacher', auth: [:email_token] do
    create_password_form = CreatePasswordForm.new(params)
    if create_password_form.valid?
      result = SaveTeacherPassword.new(
        settings.api_root, @email_token, params['password']).call
      redirect LOGOUT if result.code == 401
      session[:regular_token] = result.body
      redirect '/tokens'
    else
      flash[:error] = "#{create_password_form.error_message}."
      redirect '/welcome'
    end
  end

  get '/tokens/?', auth: [:email_token, :regular_token] do
    result = GetListOfTokens.new(settings.api_root, @regular_token).call
    redirect LOGOUT if result.code == 401
    tokens = JSON.parse result.body
    slim :tokens, locals: { tokens: tokens }
  end

  post '/tokens/?', auth: [:email_token, :regular_token] do
    save_token_form = SaveTokenForm.new(params)
    if save_token_form.valid?
      result = SaveToken.new(settings.api_root, @regular_token, params).call
      redirect LOGOUT if result.code == 401
      result = result.body
      msg = result.include?('saved') ? :notice : :error
      flash[msg] = "#{result}"
    else flash[:error] = "#{save_token_form.error_message}."
    end
    redirect '/tokens'
  end

  get '/tokens/:access_key/?', auth: [:email_token, :regular_token] do
    result = GetListOfCourses.new(
      settings.api_root, @regular_token, params['access_key']).call
    redirect LOGOUT if result.code == 401
    courses = result.body
    invalid_token?(courses)
    slim :courses, locals: { courses: JSON.parse(courses),
                             token: params['access_key'] }
  end

  delete '/tokens/:access_key/?', auth: [:email_token, :regular_token] do
    result = DeleteToken.new(
      settings.api_root, @regular_token, params['access_key']).call
    if result.code == 200 then flash[:notice] = 'Successfully deleted!'
    elsif result.code == 403 then flash[:error] = 'You do not own this token!'
    elsif result.code == 401 then redirect LOGOUT
    else flash[:error] = 'This is a strange one :('
    end
    redirect '/tokens'
  end

  get '/tokens/:access_key/:course_id/dashboard/?',
      auth: [:email_token, :regular_token] do
    activity, assignments, discussion_topics, student_summaries =
    %w(activity assignments discussion_topics student_summaries).map do |link|
      params['data'] = link
      result = GetCourseData.new(settings.api_root, @regular_token, params).call
      redirect LOGOUT if result.code == 401
      invalid_token?(result.body)
      result.body
    end
    slim :dashboard, locals: {
      activities: JSON.parse(activity, quirks_mode: true),
      assignments: JSON.parse(assignments, quirks_mode: true),
      discussions_list: JSON.parse(discussion_topics, quirks_mode: true),
      student_summaries: JSON.parse(student_summaries, quirks_mode: true)
    }
  end

  get '/tokens/:access_key/:course_id/:data/?',
      auth: [:email_token, :regular_token] do
    check_data = CheckData.new(data: params['data'])
    unless check_data.valid?
      flash[:error] = 'Please click an actual option'
      redirect "/tokens/#{params[:access_key]}"
    end
    result = GetCourseData.new(settings.api_root, @regular_token, params).call
    redirect LOGOUT if result.code == 401
    result = result.body
    invalid_token?(result)
    slim :"#{params['data']}",
         locals: { data: JSON.parse(result, quirks_mode: true) }
  end
end
