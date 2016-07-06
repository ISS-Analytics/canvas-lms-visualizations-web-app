# Object to save teacher password
class SaveTeacherPassword
  def initialize(api, encrypted_email, password)
    @api = api
    @payload = encrypted_email
    @password = password
  end

  def call
    HTTParty.post("#{@api}/save_password",
                  body: { password: @password },
                  headers: { 'AUTHORIZATION' => "Bearer #{@payload}" })
  end
end
