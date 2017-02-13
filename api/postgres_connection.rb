require 'pg'

class PostgresConnection
  def initialize(db_provider)
    @connection = nil
    @db_provider = db_provider # :heroku, :aws, :local
  end

  def get_all_tracks(finalized)
    return [false, internal_error] unless ensure_connection
    res = @connection.exec("SELECT id FROM racingtrack WHERE finalized = #{finalized}")
    all_tracks = res.map { |tuple| get_track(tuple['id'])[1] }
    [true, all_tracks]
  rescue PG::Error => e
    puts(e)
    [false, internal_error]
  end

  def get_track(id, with_positions = true)
    return [false, internal_error] unless ensure_connection
    res = @connection.exec("SELECT id,name,finalized FROM racingtrack WHERE id = #{id}")
    puts res.num_tuples.zero?
    return [false, error(400, 'ID not valid.')] if res.num_tuples.zero?

    r = res.first
    racingtrack = {
      id: r['id'].to_i,
      name: r['name'],
      finalized: r['finalized'] == 't',
      positions: []
    }

    if with_positions
      positions = @connection.exec("SELECT timestamp,longitude,latitude FROM position WHERE racingtrackid = #{id}")
      racingtrack[:positions] = positions.map do |pos|
        {
          timestamp: pos['timestamp'].to_i,
          latitude: pos['latitude'].to_f,
          longitude: pos['longitude'].to_f
        }
      end .sort_by { |pos| pos[:timestamp] }
    end

    [true, racingtrack]
  rescue PG::Error => e
    puts(e)
    [false, internal_error]
  end

  def get_position(track_id, timestamp)
    return [false, internal_error] unless ensure_connection
    pos = @connection.exec("SELECT timestamp,longitude,latitude FROM position WHERE racingtrackid = #{track_id} AND timestamp = #{timestamp}")
    return [false, internal_error] if pos.num_tuples.zero?

    p = pos[0]
    position = {
      timestamp: p['timestamp'].to_i,
      latitude: p['latitude'].to_f,
      longitude: p['longitude'].to_f
    }

    [true, position]
  rescue PG::Error => e
    puts(e.message)
    [false, internal_error]
  end

  def store_track(name, finalized, positions)
    return [false, internal_error] unless ensure_connection
    id = @connection.exec("SELECT nextval('racingtrackid')")[0]['nextval']
    @connection.exec("INSERT INTO racingtrack(id, name, finalized) VALUES (#{id}, '#{name}', '#{finalized}')")

    positions.each do |item|
      latitude = item['latitude']
      longitude = item['longitude']
      timestamp = item['timestamp']
      store_position(id, timestamp, latitude, longitude)
    end

    get_track(id)

  rescue PG::Error => e
    puts(e)
    [false, internal_error]
  end

  def delete_track(id)
    return [false, internal_error] unless ensure_connection
    res1 = @connection.exec("DELETE FROM position WHERE racingtrackid = #{id}")
    res2 = @connection.exec("DELETE FROM racingtrack WHERE id = #{id}")

    return [false, internal_error] unless res1 || res2
    return [false, error(400, 'ID not valid')] if res1.cmd_tuples.zero? || res2.cmd_tuples.zero?

    [true, nil] # -> empty response
  rescue PG::Error => e
    puts(e.message)
    [false, internal_error]
  end

  def finalize_track(track_id)
    return [false, internal_error] unless ensure_connection
    res = @connection.exec("UPDATE racingtrack SET finalized = TRUE WHERE id = #{track_id} AND finalized = FALSE")
    return [false, internal_error] unless res
    return [false, error(403, 'Racing track is already finalized.')] if res.cmd_tuples.zero?

    get_track(track_id)
  rescue PG::Error => e
    puts(e.message)
    [false, internal_error]
  end

  def store_position(track_id, timestamp, latitude, longitude)
    if latitude.is_a?(Float) == false || longitude.is_a?(Float) == false ||
       latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180 ||
       timestamp.is_a?(Integer) == false || timestamp < 0
      [false, error(400, 'Parameter not valid.')]
    end

    is_existing, = get_position(track_id, timestamp)
    return [false, error(400, 'Timestamp already existing')] if is_existing

    res = @connection.exec("INSERT INTO position(racingtrackid, timestamp, latitude, longitude) VALUES (#{track_id}, #{timestamp}, #{latitude}, #{longitude})")
    return [false, error(400, 'Parameter not valid.')] if res.cmd_tuples.zero?
    get_position(track_id, timestamp)
  rescue PG::Error => e
    puts(e.message)
    [false, internal_error]
  end

  private

  def ensure_connection
    if @connection.nil? || @connection.status != PGconn::CONNECTION_OK
      @connection = connect
    end

    !@connection.nil?
  end

  def connect
    if @db_provider == :heroku
      PGconn.connect(
        host: 'ec2-176-34-113-15.eu-west-1.compute.amazonaws.com',
        port: 5432,
        dbname: 'dd3g9rn58i7rv5',
        user: 'ffrhqdydlknkrf',
        password: '876c66600f776cb251b586235325011d81a38c791eab56e3a5556611996bb61a'
      )
    elsif @db_provider == :aws
      PGconn.connect(
        host: 'aa4lkpxdxfr6cq.cgfneacm965e.us-east-1.rds.amazonaws.com',
        port: 5432,
        dbname: 'ebdb',
        user: 'ffrhqdydlknkrf',
        password: '876c66600f776cb251b586235325011d81a38c791eab56e3a5556611996bb61a'
      )
    elsif @db_provider == :local
      PGconn.connect(hostaddr: '127.0.0.1', port: 5432, dbname: 'postgres', user: 'postgres', password: 'password')
    end
  rescue PG::Error => e
    puts e.message
  end

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
end
