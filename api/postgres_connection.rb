require 'pg'

class PostgresConnection

	def initialize(db_provider)
		@connection = nil
		@db_provider = db_provider # :heroku, :aws, :local
	end

	def connect
	  begin
	    if @db_provider == :heroku
				@connection=PGconn.connect(
					:host => "ec2-176-34-113-15.eu-west-1.compute.amazonaws.com", 
					:port => 5432, 
					:dbname => "dd3g9rn58i7rv5", 
					:user => "ffrhqdydlknkrf", 
					:password => '876c66600f776cb251b586235325011d81a38c791eab56e3a5556611996bb61a')
      elsif @db_provider == :aws
				@connection=PGconn.connect(
					:host => "aa4lkpxdxfr6cq.cgfneacm965e.us-east-1.rds.amazonaws.com", 
					:port => 5432,
					:dbname => "ebdb", 
					:user => "ffrhqdydlknkrf", 
					:password => '876c66600f776cb251b586235325011d81a38c791eab56e3a5556611996bb61a')
      elsif db
      	@connection=PGconn.connect(:hostaddr => "127.0.0.1", :port => 5432, :dbname => "postgres", :user => "postgres", :password => 'password')
      end
	    true
	  rescue PG::Error => e
	    puts e.message
	    false
  	end
	end

	def get_all_tracks(finalized)
		begin
	    res = @connection.exec("SELECT id FROM racingtrack WHERE finalized = #{finalized}");
	    all_tracks = res.map {|tuple| get_track(tuple["id"])}
	    [true, all_tracks]
	  rescue PG::Error => e
	    puts(e)
	    [false, internal_error]
	  end
	end

	def get_track(id, with_positions=true)
		begin
	    res = @connection.exec("SELECT id,name,finalized FROM racingtrack WHERE id = #{id}")

	    if res.num_tuples.zero? then
	      return [false, error(400, "ID not valid.")]
	    else
	      r = res.first
	      racingtrack = {
	        id: r['id'].to_i,
	        name: r['name'],
	        finalized: r['finalized']=='t',
	        positions:[]
	      }

	      if with_positions
	      	positions = @connection.exec("SELECT timestamp,longitude,latitude FROM position WHERE racingtrackid = #{id}")
		      racingtrack[:positions] = positions.map do |pos|
		        {
		          timestamp: pos['timestamp'].to_i,
		          latitude: pos['latitude'].to_f,
		          longitude: pos['longitude'].to_f
		        } 
		      end .sort_by {|pos| pos[:timestamp]}
	      end

	      [true, racingtrack]
	    end
	  rescue PG::Error => e
	    puts(e)
	    [false, internal_error]
	  end
	end

	def get_position(track_id, timestamp)
		pos = @connection.exec("SELECT timestamp,longitude,latitude FROM position WHERE racingtrackid = #{track_id} AND timestamp = #{timestamp}")
    return [false, internal_error] if pos.num_tuples.zero?

    p = pos[0]
    position = {
      timestamp: p['timestamp'].to_i,
      latitude: p['latitude'].to_f,
      longitude: p['longitude'].to_f
    }

    [true, position]
	end

	def store_track(name, finalized, positions)
		begin
      id = @connection.exec("SELECT nextval('racingtrackid')")[0]["nextval"]
      res = @connection.exec("INSERT INTO racingtrack(id, name, finalized) VALUES (#{id}, '#{name}', '#{finalized}')")

      positions.each do |pos|
      	latitude = item["latitude"]
        longitude = item["longitude"]
        timestamp = item["timestamp"]
        store_position(id, timestamp, latitude, longitude)
      end

      get_track(id)

    rescue PG::Error => e
	    puts(e)
	    [false, internal_error]
	  end
	end

	def delete_track(id)
		begin
	    res1 = @connection.exec("DELETE FROM position WHERE racingtrackid = #{id}")
      res2 = @connection.exec("DELETE FROM racingtrack WHERE id = #{id}")

      return [false,internal_error] unless res1 || res2
      return [false,error(400,"ID not valid")] if res1.cmd_tuples == 0 || res2.cmd_tuples == 0

      [true, nil] # -> empty response
	  rescue PG::Error => e
	    puts(e.message)
	    [false, internal_error]
		end
	end

	def finalize_track(id)
		res = @connection.exec("UPDATE racingtrack SET finalized = TRUE WHERE id = #{int_id} AND finalized = FALSE")
    return [false, internal_error] unless res
    return [false, error(403, "Racing track is already finalized.")]  if res.cmd_tuples == 0

    get_track(id)
	end

	def store_position(track_id, timestamp, latitude, longitude)

		res = @connection.exec("INSERT INTO position(racingtrackid, timestamp, latitude, longitude) VALUES (#{track_id}, #{timestamp}, #{latitude}, #{longitude})")
		return [false,error(400, "Parameter not valid.")] if res2.cmd_tuples == 0
		get_position(track_id)
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
		error(500,"Unexpected internal error")
	end

end