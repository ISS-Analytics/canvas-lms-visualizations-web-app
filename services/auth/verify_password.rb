# Object to verify password provided by user
class VerifyPassword
  def initialize(api, email, password)
    @api = api
    @email = email
    @password = password
  end

  def call
    payload = EncryptPayload.new(
      { email: @email, password: @password }.to_json).call
    HTTParty.get("#{@api}/verify_password",
                 headers: { 'AUTHORIZATION' => "Bearer #{payload}" }).body
  end
end
