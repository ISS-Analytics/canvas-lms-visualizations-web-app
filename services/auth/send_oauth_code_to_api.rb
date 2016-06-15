# Object to send code from Google OAuth to API
class SendOAuthCodeToAPI
  def initialize(oauth_code)
    @oauth_code = oauth_code
  end

  def call
    HTTParty.get("#{ENV['API_URL']}use_callback_code?code=#{@oauth_code}").body
  end
end
