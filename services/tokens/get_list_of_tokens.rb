# Object to get list of tokens
class GetListOfTokens
  def initialize(api, regular_token)
    @api = api
    @payload = regular_token
  end

  def call
    HTTParty.get("#{@api}/tokens",
                 headers: { 'AUTHORIZATION' => "Bearer #{@payload}" })
  end
end
