# Object to get OAuth client_id from API
class GetOAuthClientIDFromAPI
  def call
    HTTParty.get("#{ENV['API_URL']}client_id").body
  end
end
