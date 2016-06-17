# Object to save teacher password
class SaveTeacherPassword
  def initialize(api, email, password)
    @api = api
    @email = email
    @password = password
  end

  def call
    payload = EncryptPayload.new(
      { email: @email, password: @password }.to_json).call
    HTTParty.post("#{@api}/save_password",
                  headers: { 'AUTHORIZATION' => "Bearer #{payload}" })
  end
end
