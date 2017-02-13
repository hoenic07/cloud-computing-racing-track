require 'redis'

class RedisConnection
  def initialize(db_provider)
    @connection = nil
    @db_provider = db_provider # :local
  end

  def connect
    if @db_provider == :heroku
      # TODO
    elsif @db_provider == :aws
      # TODO?
    elsif @db_provider == :local
      @connection = Redis.new(
        host: '127.0.0.1',
        port: 6379
      )
    end
    true
  rescue => e
    puts e.message
    false
  end

  def get_all_tracks(finalized)
    key_tracks = finalized ? 'finalizedTracks' : 'activeTracks'
    tracks = @connection.smembers(key_tracks)

    all_tracks = []

    tracks.each do |track_id|
      all_tracks.push(get_track(track_id, true))
    end

    [true, all_tracks]
  rescue => e
    puts(e)
    [false, internal_error]
  end

  def get_track(track_id, with_positions = true)
    # begin
    if @connection.sismember('finalizedTracks', track_id)
      finalized = true
    elsif @connection.sismember('activeTracks', track_id)
      finalized = false
    else
      return [false, error(400, 'ID not valid')]
    end

    track_name = @connection.hget('racingtrack:' + track_id.to_s, 'name')

    if track_name.nil?
      puts('Error in DB - racing track ' + track_id.to_s + ' has no name.')
    end

    track = {
      id: track_id.to_i,
      name: track_name.to_s,
      finalized: finalized,
      positions: []
    }

    if with_positions
      timestamps = @connection.smembers('racingtrack:' + track_id.to_s + ':timestamp')

      positions = []
      timestamps.each do |timestamp|
        success, position = get_position(track_id, timestamp)
        positions.push(position) if success
      end

      track[:positions] = positions
    end

    [true, track]
    # rescue => e
    #   puts(e)
    #   [false, internal_error]
    # end
  end

  def store_track(name, finalized, positions)
    id = @connection.incr('racingtrackid')

    @connection.hset('racingtrack:' + id.to_s, 'name', name)

    key_tracks = finalized ? 'finalizedTracks' : 'activeTracks'

    @connection.sadd(key_tracks, id)

    positions.each do |item|
      latitude = item['latitude']
      longitude = item['longitude']
      timestamp = item['timestamp']
      store_position(id, timestamp, latitude, longitude)
    end

    get_track(id)
  rescue => e
    puts(e)
    [false, internal_error]
  end

  def delete_track(track_id)
    #  begin
    success, payload = get_track(track_id, true)
    puts success
    return [success, payload] unless success # error_pl(payload).to_json unless success

    track = payload

    track[:finalized] ? key_tracks = 'finalizedTracks' : 'activeTracks'

    @connection.srem(key_tracks, track_id)

    puts track

    track[:positions].each do |position|
      timestamp = position[:timestamp]

      puts timestamp
      puts timestamp.class
      @connection.srem('racingtrack:' + track_id.to_s + ':timestamp', timestamp)
      timestamp_key = 'racingtrack:' + track_id.to_s + ':' + timestamp.to_s
      @connection.hdel(timestamp_key, 'latitude')
      @connection.hdel(timestamp_key, 'longitude')
    end

    @connection.hdel('racingtrack:' + track_id.to_s, 'name')

    [true, nil] # -> empty response
    # rescue => e
    #  puts(e)
    #  [false, internal_error]
    # end
  end

  def finalize_track(track_id)
    is_finalized = @connection.sismember('finalizedTracks', track_id)
    return [false, error(400, 'ID not valid')] unless is_finalized || @connection.sismember('activeTracks', track_id)
    return [false, error(403, 'Racing track is already finalized.')] if @connection.sismember('finalizedTracks', track_id)

    @connection.srem('activeTracks', track_id)
    @connection.sadd('finalizedTracks', track_id)

    [true, get_track(track_id, true)]
  rescue => e
    puts(e)
    [false, internal_error]
  end

  def store_position(track_id, timestamp, latitude, longitude)
    if latitude.is_a?(Float) == false || longitude.is_a?(Float) == false ||
       latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180 ||
       timestamp.is_a?(Integer) == false || timestamp < 0
      return [false, error(400, 'Parameter not valid.')]
    end

    begin
      @connection.sadd('racingtrack:' + track_id.to_s + ':timestamp', timestamp)
      @connection.hmset('racingtrack:' + track_id.to_s + ':' + timestamp.to_s, 'latitude', latitude, 'longitude', longitude)

      [true, get_position(track_id, timestamp)]
    rescue => e
      puts(e)
      [false, internal_error]
    end
  end

  private

  def error(code, message)
    {
      errorModel: {
        code: code.to_i,
        message: message
      }
    }
  end

  def internal_error
    error(500, 'Unexpected internal error')
  end

  def get_position(track_id, timestamp)
    pos_value = @connection.hmget('racingtrack:' + track_id.to_s + ':' + timestamp.to_s, 'latitude', 'longitude')

    # TODO: pos_value nil check necessary?

    lng_val = pos_value.pop.to_i
    lat_val = pos_value.pop.to_i

    if lat_val.nil? || lng_val.nil? || !lat_val.is_a?(Numeric) || !lng_val.is_a?(Numeric)
      # ignore invalid lat/lng values => return nil
      puts('Invalid lat or lng value for racing track #' + track_id.to_s + ' and timestamp ' + timestamp.to_s)

      return [false, internal_error]
    end

    position = {
      timestamp: timestamp.to_i,
      latitude: lat_val.to_f,
      longitude: lng_val.to_f
    }

    [true, position]
  end
end
