require 'redis'

class RedisConnection

  def initialize(db_provider)
    @connection = nil
    @db_provider = db_provider # :aws :local
  end

  def connect
    begin
      if @db_provider == :heroku
#TODO
#:host => "ec2-176-34-113-15.eu-west-1.compute.amazonaws.com",
#    :port => 5432,
#    :dbname => "dd3g9rn58i7rv5",
#    :user => "ffrhqdydlknkrf",
#    :password => '876c66600f776cb251b586235325011d81a38c791eab56e3a5556611996bb61a')
      elsif @db_provider == :aws
        @connection=Redis.new(
            :host => 'ec2-34-249-143-159.eu-west-1.compute.amazonaws.com',
            :port => 23619,
            :user => 'h',
            :password => 'p44062d44f046721f9cfe9df9da49c7e786f299c5dca666be0e8dad33b178e379'
        )

      elsif @db_provider == :local
        @connection=Redis.new(
            :host => '127.0.0.1',
            :port => 6379)
      end
      true
    rescue => e
      puts e.message
      false
    end
  end

  def get_all_tracks(finalized)
    begin
      key_tracks = finalized ? 'finalizedTracks' : 'activeTracks'
      tracks = @connection.smembers(key_tracks)

      all_tracks = Array.new

      tracks.each do |track_id|
        success, payload = get_track(track_id, true)

        puts (payload) unless success
        all_tracks.push(payload) if success
      end

      [true, all_tracks]
    rescue => e
      puts(e)
      [false, internal_error]
    end
  end

  def get_track(track_id, with_positions=true)
    begin
      if @connection.sismember('finalizedTracks', track_id) then
        finalized = true
      elsif @connection.sismember('activeTracks', track_id) then
        finalized = false
      else
        return [false, error(400, 'ID not valid')]
      end

      track_name = @connection.hget("racingtrack:#{track_id}", 'name')

      return puts("Error in DB - racing track #{track_id} has no name.") if track_name.nil?

      track = {
          :racingTrack => {
              id: track_id.to_i,
              name: track_name.to_s,
              finalized: finalized,
              positions: []
          }
      }

      if with_positions
        timestamps = @connection.smembers("racingtrack:#{track_id}:timestamp")

        positions = []
        timestamps.each do |timestamp|
          success, position = get_position(track_id, timestamp)
          positions.push(position) if success
        end

        track[:racingTrack][:positions] = positions
      end

      [true, track]
    rescue => e
      puts(e)
      [false, internal_error]
    end
  end

  def store_track(name, finalized, positions)
    begin
      id = @connection.incr('racingtrackid')

      @connection.hset("racingtrack: #{id}", 'name', name)

      key_tracks = finalized ? 'finalizedTracks' : 'activeTracks'

      @connection.sadd(key_tracks, id)

      positions.each do |item|
        latitude = item['latitude']
        longitude = item['longitude']
        timestamp = item['timestamp']
        success, payload = store_position(id, timestamp, latitude, longitude)
        puts("Could not store position #{positions}: #{payload}") unless success
      end

      [true, get_track(id)]
    rescue => e
      puts(e)
      [false, internal_error]
    end
  end

  def delete_track(track_id)
    begin
      success, payload = get_track(track_id, true)

      return [success, payload] unless success

      track = payload[:racingTrack]

      @connection.srem(track[:finalized] ? 'finalizedTracks' : 'activeTracks', track_id)

      track[:positions].each do |position|
        timestamp = position[:timestamp]

        @connection.srem("racingtrack:#{track_id}:timestamp", timestamp)
        timestamp_key = "racingtrack:#{track_id}:#{timestamp}"
        @connection.hdel(timestamp_key, 'latitude')
        @connection.hdel(timestamp_key, 'longitude')
      end

      @connection.hdel("racingtrack:#{track_id}", 'name')

      [true, nil] # -> empty response
    rescue => e
      puts(e)
      [false, internal_error]
    end
  end

  def finalize_track(track_id)
    begin
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
  end

  def store_position(track_id, timestamp, latitude, longitude)


    if latitude.is_a?(Float) == false || longitude.is_a?(Float) == false ||
        latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180 ||
        timestamp.is_a?(Integer) == false || timestamp < 0
      return [false, error(400, 'Parameter not valid.')]
    end

    begin
      @connection.sadd("racingtrack:#{track_id}:timestamp", timestamp)
      @connection.hmset("racingtrack:#{track_id}:#{timestamp}", 'latitude', latitude, 'longitude', longitude)

      success, payload = get_position(track_id, timestamp)

      return [false, payload] unless success

      position = {
          :position => payload
      }

      [true, position]
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
    pos_value = @connection.hmget("racingtrack:#{track_id}:#{timestamp}", 'latitude', 'longitude')

    lng_val = pos_value.pop.to_f
    lat_val = pos_value.pop.to_f

    if lat_val.nil? || lng_val.nil? || !(lat_val.is_a?(Numeric)) || !(lng_val.is_a?(Numeric)) then
      # ignore invalid lat/lng values => return nil
      puts("Invalid lat or lng value for racing track #{track_id} and timestamp #{timestamp}")

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