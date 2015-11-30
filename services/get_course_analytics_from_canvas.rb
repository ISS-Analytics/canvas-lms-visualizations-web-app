# Service Object that gets course analytics from Canvas API
# Depends on what info is request, this covers a number of API calls
class GetCourseAnalyticsFromCanvas
  def initialize(canvas_api, canvas_token, course_id, data)
    @url = canvas_api + 'courses/' + course_id + "/analytics/#{data}"
    @canvas_token = canvas_token
  end

  def call
    visit_canvas = VisitCanvasAPI.new(@url, @canvas_token)
    visit_canvas.call
  end
end
