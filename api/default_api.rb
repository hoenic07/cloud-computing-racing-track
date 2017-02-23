require 'json'
require 'date'
require 'logdna'

$myLogger = Logger.new(STDOUT)
$myLogger.level = Logger::DEBUG

db_con = PostgresConnection.new(:heroku)
# db_con = RedisConnection.new(:aws)
db_con.connect

MyApp.add_route('GET', '/swagger') do
  cross_origin
  File.read(File.join('static', 'swagger.json'))
end

MyApp.add_route('POST', '/racingTracks', 'resourcePath' => '/Default',
                'summary' => '',
                'nickname' => 'create_racing_track',
                'responseClass' => 'racingTrack',
                'endpoint' => '/racingTracks',
                'notes' => 'Creates a new racing track with a given namen and returns the racing track object which id is needed to update and finalize the racing track. Optionally position can be initally be added and the track can also be finalized. The ID of the racing track is server side generated.',
                'parameters' => [
                    {
                        'name' => 'body',
                        'description' => 'body in form of a racing track',
                        'dataType' => 'RacingTrack',
                        'paramType' => 'body'
                    }
                ]) do
  cross_origin
  content_type 'application/json'
  
  $myLogger.debug { "Incoming Request to POST /racingTracks"}
  
  begin
    body = JSON.parse(request.body.read)
  rescue JSON::ParserError, ArgumentError => e
    $myLogger.error {"API Error: #{e.message}"}
    return err(400, 'Parameter not valid.')
  end

  racing_track = body['racingTrack']
  return err(400, 'Parameter not valid') unless racing_track

  name = racing_track['name']
  finalized = racing_track['finalized'] || false
  positions = racing_track['positions'] || []
  # other parameters are ignored

  return err(400, 'Parameter not valid') if name.is_a?(String) == false || name.nil? || name.empty? || positions.is_a?(Array) == false
  return err(400, 'Parameter not valid') unless finalized == true || finalized == false
  respond_with(db_con.store_track(name, finalized, positions), 201)
end

MyApp.add_route('DELETE', '/racingTracks/{id}', 'resourcePath' => '/Default',
                'summary' => '',
                'nickname' => 'delete_racing_track',
                'responseClass' => 'void',
                'endpoint' => '/racingTracks/{id}',
                'notes' => 'Deletes a single racing track based on the ID supplied',
                'parameters' => [
                    {
                        'name' => 'id',
                        'description' => 'ID of racing track to delete',
                        'dataType' => 'int',
                        'paramType' => 'path'
                    }
                ]) do |id|
  cross_origin
  content_type 'application/json'

  $myLogger.debug { "Incoming Request to DELETE /racingTracks/{id}"}

  is_id_valid, int_id = validate_int(id)
  return err(400, 'Invalid ID.') unless is_id_valid

  respond_with(db_con.delete_track(int_id), 204)
end

MyApp.add_route('POST', '/racingTracks/{id}/finalize', 'resourcePath' => '/Default',
                'summary' => '',
                'nickname' => 'finalize_racing_track',
                'responseClass' => 'racingTrack',
                'endpoint' => '/racingTracks/{id}/finalize',
                'notes' => 'Finalizes a racing track to prevent editing based on the ID supplied',
                'parameters' => [
                    {
                        'name' => 'id',
                        'description' => 'ID of racing track to update',
                        'dataType' => 'int',
                        'paramType' => 'path'
                    }
                ]) do |id|
  cross_origin
  content_type 'application/json'

  $myLogger.debug { "Incoming Request to POST /racingTracks/{id}/finalize"}

  is_id_valid, int_id = validate_int(id)
  return err(400, 'Invalid ID.') unless is_id_valid

  success, payload = db_con.get_track(int_id, false)
  return error_pl(payload).to_json unless success

  respond_with db_con.finalize_track(int_id)
end

MyApp.add_route('GET', '/racingTracks', 'resourcePath' => '/Default',
                'summary' => '',
                'nickname' => 'find_racing_track',
                'responseClass' => 'array[racingTrack]',
                'endpoint' => '/racingTracks',
                'notes' => 'Returns all finalized racing tracks from the system',
                'parameters' => [
                ]) do
  cross_origin
  content_type 'application/json'

  $myLogger.debug { "Incoming Request to GET /racingTracks"}

  # return an error if the value is not true, false or nil
  return err(400, 'Invalid Parameter.') unless ['true', 'false', nil].include? params['finalized']

  # set to true if true or nil
  finalized = ['true', nil].include? params['finalized']

  respond_with db_con.get_all_tracks(finalized)
end

MyApp.add_route('GET', '/racingTracks/{id}', 'resourcePath' => '/Default',
                'summary' => '',
                'nickname' => 'find_racing_track_by_id',
                'responseClass' => 'racingTrack',
                'endpoint' => '/racingTracks/{id}',
                'notes' => 'Returns a racing track based on a single ID',
                'parameters' => [
                    {
                        'name' => 'id',
                        'description' => 'ID of racing track to fetch',
                        'dataType' => 'int',
                        'paramType' => 'path'
                    }
                ]) do |id|
  cross_origin
  content_type 'application/json'

  $myLogger.debug { "Incoming Request to GET /racingTracks/{id}"}

  is_id_valid, int_id = validate_int(id)
  return err(400, 'Invalid ID.') unless is_id_valid

  respond_with db_con.get_track(int_id)
end

MyApp.add_route('POST', '/racingTracks/{id}/positions', 'resourcePath' => '/Default',
                'summary' => '',
                'nickname' => 'update_racing_track_position',
                'responseClass' => 'position',
                'endpoint' => '/racingTracks/{id}/positions',
                'notes' => 'Creates and adds a postion of a racing track as long as it is not finalized based on the ID supplied',
                'parameters' => [
                    {
                        'name' => 'id',
                        'description' => 'ID of racing track to update',
                        'dataType' => 'int',
                        'paramType' => 'path'
                    },
                    {
                        'name' => 'body',
                        'description' => 'position body',
                        'dataType' => 'Position',
                        'paramType' => 'body'
                    }
                ]) do |id|
  cross_origin
  content_type 'application/json'

  $myLogger.debug { "Incoming Request to POST /racingTracks/{id}/positions"}

  is_id_valid, int_id = validate_int(id)
  return err(400, 'Parameter not valid.') unless is_id_valid

  begin
    body = JSON.parse(request.body.read)
  rescue JSON::ParserError, ArgumentError => e
    $myLogger.error {"API Error: #{e.message}"}
    return err(400, 'Parameter not valid.')
  end

  position = body['position']

  return error(400, 'Parameter not valid.') if position.nil?

  latitude = position['latitude']
  longitude = position['longitude']
  timestamp = position['timestamp']

  success, payload = db_con.get_track(int_id, false)

  if !success
    error_pl(payload).to_json
  elsif payload[:finalized]
    err(403, 'Racing track is already finalized.')
  else
    respond_with db_con.store_position(int_id, timestamp, latitude, longitude)
  end
end

def validate_int(id)
  int_id = id.to_i
  is_valid = int_id >= 0 && int_id.to_s == id
  [is_valid, int_id]
end

def err(code, message)
  $myLogger.info { "Failed Request: #{code} - #{message}"}
  status code
  {
      errorModel: {
          code: code.to_i,
          message: message
      }
  }.to_json
end

def error_pl(payload)
  $myLogger.info { "Failed Request: #{payload[:errorModel][:code]} - #{payload[:errorModel][:message]}"}
  status payload[:errorModel][:code]
  payload
end

def internal_error
  err(500, 'Unexpected internal error')
end

def respond_with(data, success_code = 200)
  success = data[0]
  payload = data[1]
  status success_code if success
  (success ? payload : error_pl(payload)).to_json
end
