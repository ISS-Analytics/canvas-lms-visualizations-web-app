# Object to send code from Google OAuth to API
class GetEmailFromAPI
  def initialize(oauth_code)
    @oauth_code = oauth_code
  end

  def call
    result =
    HTTParty.get("#{ENV['API_URL']}use_callback_code?code=#{@oauth_code}").body
    JSON.parse result
  end
end
