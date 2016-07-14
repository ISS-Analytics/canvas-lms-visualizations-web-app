# Object to get list of courses
class GetListOfCourses
  def initialize(api, regular_token, access_key)
    @api = api
    @payload = regular_token
    @access_key = access_key
  end

  def call
    HTTParty.get("#{@api}/courses",
                 body: { 'access_key' => @access_key },
                 headers: { 'AUTHORIZATION' => "Bearer #{@payload}" })
  end
end
