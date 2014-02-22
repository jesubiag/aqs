#!/usr/bin/env ruby

require 'pg'
require 'pgpass'
require 'work_queue'
require 'timeout'

	#TODO: Add interface Class for user data input, instead of hardcoded values

class Admin

	attr_accessor :conn, :queries, :logger, :thpool, :entry
	# conn: PGconn, queries: PGresult, logger: Logger

	def initialize

		@entry = Pgpass.match( database: 'organizador' )
		@conn = PGconn.new( :dbname => @entry.database, :user => @entry.username, :password => @entry.password )
		@queries = @conn.exec( 'SELECT * FROM tareas ORDER BY id' )	# WHERE fecha=CURRENT_DATE
		@logger = Logger.new
		@thpool = WorkQueue.new( 15, 60 )
		@logger.sep

	end

	def runThreads

		@queries.each { |query| @thpool.enqueue_b { Qadm.new( query, @logger ) } }
		
	end


	def finish

		@thpool.join
		@logger.close

	end

end

class Qadm

	attr_accessor :conn, :mconn, :result, :entry, :mentry, :logger, :error_message, :query
		# mconn: Connection to main DB - updates query status, etc
		# mentry: Connection information for main DB

	def initialize( query, logger )

		@logger = logger
		@query = query
		@logger.register( "Thread #{Thread.current} comenzado", :ok )

		self.iniConn
		self.run

	end

	def iniConn

		@entry = Pgpass.match (database: @query["bd"] )
		@conn = PGconn.new( :dbname => @query["bd"], :user => @entry.username, :password => @entry.password )	#Check if connection was properly established
		@mentry = Pgpass.match( database: 'organizador' )
		@mconn = PGconn.new( :dbname => 'organizador', :user => @mentry.username, :password => @mentry.password )
		@logger.register( "Conexion #{@conn} establecida.", :ok )

	end

	def run

		begin		#Try-catch, kinda nasty

			status = Timeout::timeout( 5 ) do
				@result = @conn.async_exec( @query["tarea"] )
				if !@result.nil?
					if @result.result_status == ( PGconn::PGRES_TUPLES_OK || PGRES_COMMAND_OK || PGRES_POLLING_OK )		#It works but I'm not sure it's entirely OK
						@mconn.exec( "UPDATE tareas SET estado=TRUE WHERE id=#{@query["id"]}" )
					end
				end
			end

		rescue

			@error_message = "#{$!}"
			if @error_message == "execution expired"
				puts @error_message		#Delete this
			end

		ensure

			if @error_message.nil?
				@logger.register( "La consulta #{@query["id"]} fue ejecutada correctamente",:ok )
				return nil
			elsif @error_message == "execution expired"
				@mconn.exec( "UPDATE tareas SET estado=FALSE WHERE id=#{query["id"]}" )
				@logger.register( "La consulta #{@query["id"]} no termino a tiempo.\n#{@error_message}",:wrn )
				return nil
			else
				@mconn.exec( "UPDATE tareas SET estado=FALSE WHERE id=#{query["id"]}" )
				@logger.register( "La consulta #{@query["id"]} no se pudo realizar.\n#{@error_message}",:err )
				return nil
			end

		end

		#No PGresult & error code = "", then it didn't run
		#@result.clear

	end

end

class Logger

	attr_accessor :file, :path, :msgs

	MSGS = { :err => "ERROR", :wrn => "WARNING", :ok => "OK", :ini => "INIT" }

	def initialize

		@path="/tmp/hilos.log"
		@file = File.open (@path,"a+" )

	end
	
	def register( string, type )

		@file.puts Time.new.strftime( "%Y-%m-%d [%H:%M:%S]" ) + " == [#{MSGS[type]}] " + string		#Improve logging format. Check which messages are stored.

	end

	def sep

		@file.puts ( "\n---------------------------------------------------------\n\n" )

	end

	def close

		@file.close unless @file.nil?

	end
	
end

a = Admin.new
a.runThreads
a.finish
