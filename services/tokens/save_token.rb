# Object to save a token
class SaveToken
  def initialize(api, regular_token, params)
    @api = api
    @payload = regular_token
    @params = params
  end

  def call
    HTTParty.post("#{@api}/tokens",
                  body: @params,
                  headers: { 'AUTHORIZATION' => "Bearer #{@payload}" })
  end
end
