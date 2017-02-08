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
            getRacingTrackObj(conn, id)

          rescue PG::Error => e
            puts(e)
            sendInternalError
          else
            sendError("400", "Parameter not valid")
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
begin
    res = conn.exec("SELECT id FROM racingtrack WHERE id = #{id}")

    if res.num_tuples == 0 then
      sendError("400", "Invalid ID.")
    else
      res = conn.exec("UPDATE racingtrack SET finalized = TRUE WHERE id = #{id} AND finalized = FALSE")

      if res.nil? then
        sendInternalError
      else
        racingTrackRes = conn.exec("SELECT row_to_json(racingtrack) as racingTrack FROM racingtrack WHERE id = #{id}")

        if res.cmd_tuples == 0 then
          sendError("403", "Racing track is already finalized.")
        else
          racingtrack = racingTrackRes[0]

          res = conn.exec("SELECT array_to_json(array_agg(json_build_object('timestamp', timestamp, 'lat', latitude, 'lng', longitude))) as positions FROM position WHERE racingtrackid =  #{id}")
          racingtrack["positions"] = res[0]

          racingtrack.to_json
        end
      end
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

  res = conn.exec("SELECT id FROM racingtrack WHERE finalized = FALSE");

  result = "["

  res.each { |tuple|
    id = tuple["id"]
    result << getRacingTrackObj(conn, id)
    result << ", "
  }
  if res.num_tuples > 0
    result = result[0..-3]
  end
  result << "]"

  result
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

  getRacingTrackObj(conn, id)
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

  begin
    body = JSON.parse(request.body.read)

    position = body["position"]

    if position.nil? then
      sendError("400", "Parameter not valid.")
    else
      latitude = position["lat"]
      longitude = position["lng"]
      timestamp = position["timestamp"]

      #check values and ranges of lat, long and timestamp
      if latitude.is_a?(Float) == false || longitude.is_a?(Float) == false ||
          latitude < -90 && latitude > 90 || longitude < -180 || latitude > 180 ||
          timestamp.is_a?(Numeric) == false
        sendError("400", "Parameter not valid.")
      else
        res = conn.exec("SELECT finalized FROM racingtrack WHERE id =#{id}")

        if res.num_tuples.zero? then
          sendError("400", "Parameter not valid.")
        elsif res[0]["finalized"] == "t" then
          sendError("403", "Racing track is already finalized.")
        else

          res = conn.exec("INSERT INTO position(racingtrackid, timestamp, latitude, longitude) VALUES (#{id}, #{timestamp}, #{latitude}, #{longitude})")

          if res.cmd_tuples == 0 then
            sendError("400", "Parameter not valid.")
          else
            res = conn.exec("SELECT array_to_json(array_agg(json_build_object('timestamp', timestamp, 'lat', latitude, 'lng', longitude))) as position FROM position WHERE racingtrackid = #{id} AND timestamp = #{timestamp}")
            if res.num_tuples.zero? then
              sendInternalError
            else
              res[0].to_json
            end
          end
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
    res = conn.exec("SELECT row_to_json(racingtrack) as racingTrack FROM racingtrack WHERE id = #{id}")

    if res.num_tuples.zero? then
      sendError("400", "ID not valid.")
    else
      racingtrack = res[0]

      positions = conn.exec("SELECT array_to_json(array_agg(json_build_object('timestamp', timestamp, 'lat', latitude, 'lng', longitude))) as positions FROM position WHERE racingtrackid = #{id}")

      racingtrack["positions"] = positions[0]["positions"]

      racingtrack.to_json
    end
  rescue PG::Error => e
    puts(e)
    sendInternalError
  end
end

def sendError(code, message)
  status code
  {"errorModel" => {
      "code" => code,
      "message" => message
  }}.to_json
end

def sendInternalError
  sendError("500", "Unexpected internal error")
end