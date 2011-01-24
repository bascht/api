require 'rubygems'
require 'sinatra'
require 'active_record'

require 'config.rb'
require 'models.rb'
require 'helpers.rb'


error 403 do
	"#{Hash['error'=>'No permissions found'].to_json()}"
end

error 401 do
	"#{Hash['error'=>'Authentication failed'].to_json()}"
end

error 404 do
	"#{Hash['error'=>'No valid route'].to_json()}"
end


# the routes
get '/' do
	error 404
end

# all models (API tables) belong here
get '/:model/:action' do
	logger(params[:key],params[:model])

	if ![ "create", "read", "update", "delete" ].include?(params[:action])
		error 404
	end
	
	# get user
	user = User.find(:first, :conditions => [ "single_access_token = ?", params[:key]])

	# check if token is valid
	error 401 if user.nil?

	# get permissions
	permissions = Permission.find(:all, :joins=> :users, :conditions => {:access => params[:action], :tabelle => params[:model], :users => { :id => user.id } }) 
	if permissions.size == 0
		error 403
	end

	# TODO: Split code into different functions depending on :action

	# check for paramters like size or columns
	if params[:size]	# returns length of table
		Datahelper = Datatable.clone()
		Datahelper.set_table_name("data_#{params[:model]}")
		results = Hash["#{params[:model]} size", Datahelper.count]
	elsif params[:columns] #return an array with columns
		results = Array.new()
		permissions.each do |permission|
			results += [permission.spalte]
		end
	else
		# create select based on permissions
		columns = Array.new()
		permissions.each do |per|
			columns += [per.spalte]
		end

		##### optional parameters #####
		# limit
		limit =  params[:limit]==nil ? 10 : params[:limit].to_i;
		where = Hash.new()
		# id (one or comma separated)
		if params[:id]!=nil
			where["id"] = params[:id].split(',')#to_i
		end

		##### fetch data #####
		# Clone Datatable to have a fresh Object every time
		Datahelper = Datatable.clone()
		Datahelper.set_table_name("data_#{params[:model]}")
		results = Datahelper.find(:all, :select => columns, :limit => limit, :conditions => where)
		
	end
	
	# create json or xmlfrom result
	if params[:output] == "xml"
		"#{results.to_xml(:skip_instruct => false, :skip_types => true)}"
	else
		"#{results.to_json()}"
	end
end
