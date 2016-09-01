FIRST_KEY = 0
ERROR = 'errors'
ERROR_MSG = 'message'
ERROR_HASH = {
  'Invalid access token.' => 'Please get a new token from Canvas. This '\
    'token has expired.'
}

# Object to check if Canvas token is expired
class CheckResult
  def initialize(result)
    @result = result
  end

  def call
    result = JSON.parse(@result)
    return false unless result.class == Hash
    if result.keys[FIRST_KEY] == ERROR
      error_message = result[ERROR][FIRST_KEY][ERROR_MSG]
      result = ERROR_HASH[error_message]
      result ? result : error_message
    else false
    end
  end
end
