require 'json'
require 'pg'
require 'date'

is_production = true

begin
  if is_production
    conn=PGconn.connect(
      :host => "ec2-176-34-113-15.eu-west-1.compute.amazonaws.com", 
      :port => 5432, 
      :dbname => "dd3g9rn58i7rv5", 
      :user => "ffrhqdydlknkrf", 
      :password => '876c66600f776cb251b586235325011d81a38c791eab56e3a5556611996bb61a')
  else
    conn=PGconn.connect(:hostaddr => "127.0.0.1", :port => 5432, :dbname => "postgres", :user => "postgres", :password => 'password')
  end
rescue PG::Error => e
  puts e.message
end

MyApp.add_route("GET", "/swagger") do
  cross_origin
  File.read(File.join('static','swagger.json'))
end

MyApp.add_route('POST', '/racingTracks', {
    "resourcePath" => "/Default",
    "summary" => "",
    "nickname" => "create_racing_track",
    "responseClass" => "racingTrack",
    "endpoint" => "/racingTracks",
    "notes" => "Creates a new racing track with a given namen and returns the racing track object which id is needed to update and finalize the racing track. Optionally position can be initally be added and the track can also be finalized. The ID of the racing track is server side generated.",
    "parameters" => [
        {
            "name" => "body",
            "description" => "body in form of a racing track",
            "dataType" => "RacingTrack",
            "paramType" => "body",
        }
    ]}) do
  cross_origin
  content_type 'application/json'

  begin
    body = JSON.parse(request.body.read)

    racingTrack = body["racingTrack"]

    if racingTrack.nil? then
      sendError("400", "Parameter not valid")
    else
      name = racingTrack["name"]
      finalized = racingTrack["finalized"]
      #other parameters are ignored

      if name.is_a?(String) == false || name.nil? || name.empty? then
        sendError("400", "Parameter not valid")
      else
        if finalized.nil? then
          finalized = false
        end

        if finalized == true || finalized == false then
          begin
            id = conn.exec("SELECT nextval('racingtrackid')")[0]["nextval"]
            res = conn.exec("INSERT INTO racingtrack(id, name, finalized) VALUES (#{id}, '#{name}', '#{finalized}')")

            status 201
            getRacingTrackObj(conn, id).to_json

          rescue PG::Error => e
            puts(e)
            sendInternalError
          end
        end
      end
    end
  rescue JSON::ParserError, ArgumentError => e
    puts(e)
    sendError("400", "Parameter not valid.")
  end
end


MyApp.add_route('DELETE', '/racingTracks/{id}', {
    "resourcePath" => "/Default",
    "summary" => "",
    "nickname" => "delete_racing_track",
    "responseClass" => "void",
    "endpoint" => "/racingTracks/{id}",
    "notes" => "Deletes a single racing track based on the ID supplied",
    "parameters" => [
        {
            "name" => "id",
            "description" => "ID of racing track to delete",
            "dataType" => "int",
            "paramType" => "path",
        },
    ]}) do |id|
  cross_origin
  content_type 'application/json'
 
  is_id_valid, int_id = validate_int(id)
  return sendError("400", "Invalid ID.") unless is_id_valid

  begin
    unless conn.nil?
      res = conn.exec("DELETE FROM position WHERE racingtrackid = #{id}")
      res = conn.exec("DELETE FROM racingtrack WHERE id = #{id}")

      if res.nil? then
        sendInternalError
      elsif res.cmd_tuples == 0
        sendError("400", "ID not valid")
      else
        status 204
      end
    end
  rescue PG::Error => e
    puts(e.message)
    sendInternalError
  end
end

MyApp.add_route('POST', '/racingTracks/{id}/finalize', {
    "resourcePath" => "/Default",
    "summary" => "",
    "nickname" => "finalize_racing_track",
    "responseClass" => "racingTrack",
    "endpoint" => "/racingTracks/{id}/finalize",
    "notes" => "Finalizes a racing track to prevent editing based on the ID supplied",
    "parameters" => [
        {
            "name" => "id",
            "description" => "ID of racing track to update",
            "dataType" => "int",
            "paramType" => "path",
        },
    ]}) do |id|
  cross_origin
  content_type 'application/json'

  begin

    is_id_valid, int_id = validate_int(id)
    return sendError("400", "Invalid ID.") unless is_id_valid

    res = conn.exec("SELECT id FROM racingtrack WHERE id = #{int_id}")

    if res.num_tuples == 0 then
      sendError("400", "Invalid ID.")
    else
      res = conn.exec("UPDATE racingtrack SET finalized = TRUE WHERE id = #{int_id} AND finalized = FALSE")
      return sendInternalError unless res
      return sendError("403", "Racing track is already finalized.")  if res.cmd_tuples == 0
      getRacingTrackObj(conn,int_id).to_json
    end
  rescue PG::Error => e
    puts(e)
    sendInternalError
  end
end

MyApp.add_route('GET', '/racingTracks', {
    "resourcePath" => "/Default",
    "summary" => "",
    "nickname" => "find_racing_track",
    "responseClass" => "array[racingTrack]",
    "endpoint" => "/racingTracks",
    "notes" => "Returns all finalized racing tracks from the system",
    "parameters" => [
    ]}) do
  cross_origin
  content_type 'application/json'

  # return an error if the value is not true, false or nil
  return sendError("400", "Invalid Parameter.") unless ['true','false',nil].include? params["finalized"]

  # set to true if true or nil
  finalized = ['true',nil].include? params["finalized"]

  res = conn.exec("SELECT id FROM racingtrack WHERE finalized = #{finalized}");
  all_tracks = res.map {|tuple| getRacingTrackObj(conn,tuple["id"])}
  all_tracks.to_json
end

MyApp.add_route('GET', '/racingTracks/{id}', {
    "resourcePath" => "/Default",
    "summary" => "",
    "nickname" => "find_racing_track_by_id",
    "responseClass" => "racingTrack",
    "endpoint" => "/racingTracks/{id}",
    "notes" => "Returns a racing track based on a single ID",
    "parameters" => [
        {
            "name" => "id",
            "description" => "ID of racing track to fetch",
            "dataType" => "int",
            "paramType" => "path",
        },
    ]}) do |id|
  cross_origin
  content_type 'application/json'
  
  is_id_valid, int_id = validate_int(id)
  return sendError("400", "Invalid ID.") unless is_id_valid

  getRacingTrackObj(conn, int_id).to_json
end

MyApp.add_route('POST', '/racingTracks/{id}/positions', {
    "resourcePath" => "/Default",
    "summary" => "",
    "nickname" => "update_racing_track_position",
    "responseClass" => "position",
    "endpoint" => "/racingTracks/{id}/positions",
    "notes" => "Creates and adds a postion of a racing track as long as it is not finalized based on the ID supplied",
    "parameters" => [
        {
            "name" => "id",
            "description" => "ID of racing track to update",
            "dataType" => "int",
            "paramType" => "path",
        },
        {
            "name" => "body",
            "description" => "position body",
            "dataType" => "Position",
            "paramType" => "body",
        }
    ]}) do |id|
  cross_origin
  content_type 'application/json'

  is_id_valid, int_id = validate_int(id)
  return sendError("400", "Parameter not valid.") unless is_id_valid

  begin
    body = JSON.parse(request.body.read)

    position = body["position"]

    if position.nil? then
      sendError("400", "Parameter not valid.")
    else
      latitude = position["latitude"]
      longitude = position["longitude"]
      timestamp = position["timestamp"]

      #check values and ranges of lat, long and timestamp
      if latitude.is_a?(Float) == false || longitude.is_a?(Float) == false ||
          latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180 ||
          timestamp.is_a?(Integer) == false || timestamp < 0
        sendError("400", "Parameter not valid.")
      else
        res1 = conn.exec("SELECT finalized FROM racingtrack WHERE id =#{int_id}")

        if res1.num_tuples.zero? then
          sendError("400", "Parameter not valid.")
        elsif res1[0]["finalized"] == "t" then
          sendError("403", "Racing track is already finalized.")
        else
          res2 = conn.exec("INSERT INTO position(racingtrackid, timestamp, latitude, longitude) VALUES (#{int_id}, #{timestamp}, #{latitude}, #{longitude})")
          return sendError("400", "Parameter not valid.") if res2.cmd_tuples == 0
          
          pos = conn.exec("SELECT timestamp,longitude,latitude FROM position WHERE racingtrackid = #{int_id} AND timestamp = #{timestamp}")
          return sendInternalError if pos.num_tuples.zero?

          p = pos[0]
          position = {
            timestamp: p['timestamp'].to_i,
            latitude: p['latitude'].to_f,
            longitude: p['longitude'].to_f
          }
          position.to_json
        end
      end
    end
  rescue JSON::ParserError, ArgumentError => e
    puts(e)
    sendError("400", "Parameter not valid.")
  rescue PG::Error => e
    puts(e)
    sendInternalError
  end
end

def getRacingTrackObj(conn, id)
   begin
    res = conn.exec("SELECT id,name,finalized FROM racingtrack WHERE id = #{id}")

    if res.num_tuples.zero? then
      return sendError("400", "ID not valid.", true)
    else

      r = res.first
      racingtrack = {
        id: r['id'].to_i,
        name: r['name'],
        finalized: r['finalized']=='t',
        positions:[]
      }

      positions = conn.exec("SELECT timestamp,longitude,latitude FROM position WHERE racingtrackid = #{id}")

      racingtrack[:positions] = positions.map do |pos|
        {
          timestamp: pos['timestamp'].to_i,
          latitude: pos['latitude'].to_f,
          longitude: pos['longitude'].to_f
        } 
      end .sort_by {|pos| pos[:timestamp]}

      racingtrack
    end
  rescue PG::Error => e
    puts(e)
    sendInternalError(true)
  end
end

def sendError(code, message, no_json = false)
  status code
  er = {
    errorModel: {
      code: code.to_i,
      message: message
    }
  }

  return er.to_json unless no_json
  er
end

def validate_int(id)
  int_id = id.to_i
  is_valid = int_id >= 0 && int_id.to_s == id
  [is_valid, int_id]
end

def sendInternalError(no_json = false)
  sendError("500", "Unexpected internal error")
end