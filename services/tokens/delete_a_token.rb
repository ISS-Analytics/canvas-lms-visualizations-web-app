# Object to delete a token
class DeleteToken
  def initialize(api, regular_token, access_key)
    @api = api
    @payload = regular_token
    @access_key = access_key
  end

  def call
    HTTParty.delete("#{@api}/token",
                    body: { 'access_key' => @access_key },
                    headers: { 'AUTHORIZATION' => "Bearer #{@payload}" })
  end
end
