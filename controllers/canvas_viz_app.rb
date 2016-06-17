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
require 'concurrent'
require 'jwt'
require 'json'
require 'tilt/kramdown'

configure :development, :test do
  require 'hirb'
  Hirb.enable
  absolute_path = File.absolute_path './config/config_env.rb'
  ConfigEnv.path_to_config(absolute_path)
end

# Visualizations for Canvas LMS Classes
class CanvasVisualizationApp < Sinatra::Base
  # include AppLoginHelper
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
        if (types.include? :teacher) && !@current_teacher
          flash[:error] = 'You must be logged in to view that page'
          redirect '/'
        elsif (types.include? :token_set) && !@token_set
          flash[:error] = 'You must enter a password to view that page'
          redirect '/welcome'
        end; end
    end
  end

  before do
    @current_teacher = GetTeacherInSessionVar.new(session[:auth_token]).call
    @token_set = GetPasswordInSessionVar.new(session[:unleash_token]).call
  end

  get '/' do
    google_url = GetOAuthClientIDFromAPI.new.call
    slim :index, locals: { google_url: google_url }
  end

  get '/oauth2callback_gmail/?' do
    email_as_jwt = GetEmailFromAPIAsJWT.new(params['code']).call
    session[:auth_token] = email_as_jwt
    redirect '/welcome'
  end

  get '/logout/?' do
    session[:auth_token] = nil
    session[:unleash_token] = nil
    flash[:notice] = 'Logged out'
    redirect '/'
  end

  get '/welcome/?', auth: [:teacher] do
    slim :welcome
  end

  post '/retrieve', auth: [:teacher] do
    password = params['password']
    result = VerifyPassword.new(
      settings.api_root, @current_teacher, password).call
    if result == 'no password found'
      flash[:error] = 'You\'re yet to save a password.'
      redirect '/welcome'
    elsif result == 'wrong password'
      flash[:error] = 'Wrong Password'
      redirect '/welcome'
    end
    session[:unleash_token] = result
    redirect '/tokens'
  end

  post '/new_teacher', auth: [:teacher] do
    create_password_form = CreatePasswordForm.new(params)
    if create_password_form.valid?
      session[:unleash_token] = SaveTeacherPassword.new(
        settings.api_root, @current_teacher, params['password']).call
      redirect '/tokens'
    else
      flash[:error] = "#{create_password_form.error_message}."
      redirect '/welcome'
    end
  end

  get '/tokens/?', auth: [:teacher, :token_set] do
    payload = TokenSetPayload.new(@current_teacher, @token_set).payload
    url = "#{settings.api_root}/tokens"
    headers = { 'AUTHORIZATION' => "Bearer #{payload}" }
    tokens = HTTParty.get(url, headers: headers)
    tokens = CreatePayloadForDevs.new(
      tokens, @current_teacher, @token_set).call
    slim :tokens, locals: { tokens: tokens }
  end

  post '/tokens/?', auth: [:teacher, :token_set] do
    save_token_form = SaveTokenForm.new(params)
    if save_token_form.valid?
      payload = TokenSetParamsPayload.new(
        @current_teacher, @token_set, params).payload
      url = "#{settings.api_root}/tokens"
      headers = { 'AUTHORIZATION' => "Bearer #{payload}" }
      result = HTTParty.post(url, headers: headers)
      msg = result.include?('saved') ? :notice : :error
      flash[msg] = "#{result}"
    else flash[:error] = "#{save_token_form.error_message}."
    end
    redirect '/tokens'
  end

  get '/tokens/:access_key/?', auth: [:teacher, :token_set] do
    payload = AccessKeyTokenSetPayload.new(
      @current_teacher, params['access_key'], @token_set).payload
    url = "#{settings.api_root}/courses"
    headers = { 'AUTHORIZATION' => "Bearer #{payload}" }
    courses = HTTParty.get(url, headers: headers).body
    slim :courses, locals: { courses: JSON.parse(courses),
                             token: params['access_key'] }
  end

  delete '/tokens/:access_key/?', auth: [:teacher, :token_set] do
    payload = AccessKeyPayload.new(
      @current_teacher, params['access_key']).payload
    url = "#{settings.api_root}/token"
    headers = { 'AUTHORIZATION' => "Bearer #{payload}" }
    result = HTTParty.delete(url, headers: headers).code
    if result == 200 then flash[:notice] = 'Successfully deleted!'
    elsif result == 401 then flash[:error] = 'You do not own this token!'
    else flash[:error] = 'This is a strange one :('
    end
    redirect '/tokens'
  end

  get '/tokens/:access_key/:course_id/dashboard/?',
      auth: [:teacher, :token_set] do
    payload = AccessKeyTokenSetPayload.new(
      @current_teacher, params['access_key'], @token_set).payload
    url = "#{settings.api_root}/courses/#{params['course_id']}/"
    headers = { 'AUTHORIZATION' => "Bearer #{payload}" }
    activity, assignments, discussion_topics, student_summaries =
    %w(activity assignments discussion_topics student_summaries).map do |link|
      HTTParty.get("#{url}#{link}", headers: headers)
    end
    slim :dashboard, locals: {
      activities: JSON.parse(activity, quirks_mode: true),
      assignments: JSON.parse(assignments, quirks_mode: true),
      discussions_list: JSON.parse(discussion_topics, quirks_mode: true),
      student_summaries: JSON.parse(student_summaries, quirks_mode: true)
    }
  end

  get '/tokens/:access_key/:course_id/:data/?',
      auth: [:teacher, :token_set] do
    check_data = CheckData.new(data: params['data'])
    unless check_data.valid?
      flash[:error] = 'Please click an actual option'
      redirect "/tokens/#{params[:access_key]}"
    end
    payload = AccessKeyTokenSetPayload.new(
      @current_teacher, params['access_key'], @token_set).payload
    url = "#{settings.api_root}/courses/"\
      "#{params['course_id']}/#{params['data']}"
    headers = { 'AUTHORIZATION' => "Bearer #{payload}" }
    result = HTTParty.get(url, headers: headers)
    slim :"#{params['data']}",
         locals: { data: JSON.parse(result, quirks_mode: true) }
  end
end
