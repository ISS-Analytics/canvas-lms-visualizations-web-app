# Object to get course data
class GetCourseData
  def initialize(api, regular_token, params)
    @api = api
    @payload = regular_token
    @access_key = params['access_key']
    @course_id = params['course_id']
    @data = params['data']
  end

  def call
    HTTParty.get("#{@api}/courses/#{@course_id}/#{@data}",
                 body: { 'access_key' => @access_key },
                 headers: { 'AUTHORIZATION' => "Bearer #{@payload}" })
  end
end
