class RedisConnection

	def initialize(db_provider)
		@connection = nil
		@db_provider = db_provider # ...
	end

	def connect
	  
	end

	def get_all_tracks(finalized)
		
	end

	def get_track(id, with_positions=true)
		
	end

	def get_position(track_id, timestamp)
		
	end

	def store_track(name, finalized, positions)
		
	end

	def delete_track(id)
		
	end

	def finalize_track(id)
		
	end

	def store_position(track_id, timestamp, latitude, longitude)

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