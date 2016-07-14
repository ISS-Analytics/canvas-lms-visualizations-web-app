# Object to verify password provided by user
class VerifyPassword
  def initialize(api, encrypted_email, password)
    @api = api
    @payload = encrypted_email
    @password = password
  end

  def call
    HTTParty.get("#{@api}/verify_password",
                 body: { password: @password },
                 headers: { 'AUTHORIZATION' => "Bearer #{@payload}" })
  end
end
