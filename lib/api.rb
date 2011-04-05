require 'rubygems'
require 'bundler'
Bundler.require()

require 'lib/config'

#TODO:
##validate which columns can be changed / are needed
#handle parametrized requests (do this in a generic way, which means allow every parameter which is a table column of the model too)
#validate callbacks

	set :root, APP_ROOT

	get '/' do
		throw_error 400, :message => "wrong url format."
	end

	#sync script for data from leipzig.de	
	get '/sync' do
		throw_error 400 if params['json'].nil?
		if TempSync.create(:json => params['json'])
			output :success => "record created."
		else
			output :error => "record could not be created."
		end
	end

	#temp read
	get '/sync_read' do
		count = TempSync.all.length
		last = TempSync.last
		"anzahl der datensätze: #{count} <br /><br />letzter datensatz:<br/><br/>id: #{last.id}<br />json: #{last.json}"
	end

	get '/:source/?' do
		#TODO: throw other error her, maybe a help message
		throw_error 400
	end

	#request a list in rest/rails style
	get '/:source/:model/?' do
		logger
		validate
		
		output :data => params[:model].singularize.capitalize.constantize.all(:select => only_permitted_columns, :limit => params[:limit], :offset => params[:offset]), :pagination => true
	end
	
	get '/:source/:model/search/?' do
		logger
		validate
		
		# 1. search q in all permitted columns
		permitted_columns = only_permitted_columns
		conditions = [""]
		if !params[:q].nil? && params[:q].length > 0
			conditions[0] = "(" + permitted_columns.map{|k| "#{k} LIKE ?" }.join(" OR ") + ")"
			for i in 1..permitted_columns.length
				conditions[i] = "%#{params[:q]}%"
			end
		end
		
		# 2. search other paramters
		params.each do |k,v|
			if permitted_columns.include?(k) && v.to_s.length > 0
				if(conditions[0].length > 0)
					conditions[0] << " AND #{k} LIKE ?"
				else
					conditions[0] << "#{k} LIKE ?"
				end
				conditions.push("%#{v}%")
			end
		end
		
		# no output without parameters, otherwise it would return all datasets
		if conditions.size > 1
			output :data => params[:model].singularize.capitalize.constantize.all(:select => permitted_columns, :conditions=>conditions), :pagination => false
		else
			output :error => "no search parameters."
		end
	end

	#per model requests
	#create
	post '/:source/:model' do
		logger
		validate

		data = params[:model].singularize.capitalize.constantize.new(create_only_permitted_data)
		data.class.reflect_on_all_associations.map do |assoc|
			if assoc.macro == :has_many or assoc.macro == :has_and_belongs_to_many
				unless params[assoc.name].nil?
					assoc_array =[]
					assoc_array = params[assoc.name].split(",").map{ |n| n.to_i}
					#next two lines mean for example the following: Company.sub_branch_ids = [1,2,3]
					m = assoc.name.to_s.singularize + "_ids="
					data.send m.to_sym, assoc_array
				end
			end
		end

		if data.save
			output :success => "#{params[:model].singularize.capitalize} with id = #{data.id()} was saved."
		else
			throw_error 404, :message => data.errors
		end
	end

	#read
	get '/:source/:model/:id' do
		logger
		validate
		
		begin
			output :model => params[:model].singularize.capitalize.constantize.find(params[:id], :select => only_permitted_columns)
		rescue Exception => e
			throw_error 404, :message => e.to_s
		end
	end

	#update
	put '/:source/:model/:id' do
		logger
		validate
		
		begin
			data = params[:model].singularize.capitalize.constantize.find(params[:id])
			data.class.reflect_on_all_associations.map do |assoc|
				if assoc.macro == :has_many or assoc.macro == :has_and_belongs_to_many
					unless params[assoc.name].nil?
						assoc_array =[]
						assoc_array = params[assoc.name].split(",").map{ |n| n.to_i}
						#next two lines mean for example the following: Company.sub_branch_ids = [1,2,3]
						m = assoc.name.to_s.singularize + "_ids="
						data.send m.to_sym, assoc_array
					end
				end
			end

			if data.update_attributes(create_only_permitted_data)
				output :success => "#{params[:model].singularize.capitalize} with id = #{params[:id]} was updated."
			else
				throw_error 404, :message => data.errors
			end
		rescue Exception => e
			throw_error 404, :message => e.to_s
		end
	end

	#delete
	delete '/:source/:model/:id' do
		logger
		validate
		
		data = params[:model].singularize.capitalize.constantize
		throw_error 404, :message => "#{params[:model].singularize.capitalize} does not exist." unless data.exists?(params[:id])
		begin
			data.delete(params[:id])
			output :success => "Deleted #{params[:model].singularize.capitalize} with id = #{params[:id]}."
		rescue Exception => e
			throw_error 404, :message => e.to_s
		end
	end
	
	#methods to catch all other request
	post '/*' do
		throw_error 400, :message => "wrong url format."
	end

	get '/*' do
		throw_error 400, :message => "wrong url format."
	end

	put '/*' do
		throw_error 400, :message => "wrong url format."
	end

	delete '/*' do
		throw_error 400, :message => "wrong url format."
	end
