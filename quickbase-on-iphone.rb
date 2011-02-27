require 'sinatra'
require 'QuickBaseClient'
require 'haml'

#=begin
configure do
  disable :logging
  $stdout = StringIO.new
  $stderr = StringIO.new
end
#=end

not_found do
  haml :not_found
end

get '/' do
  expires -1, :public, :must_revalidate
  haml :login
end  

get '/login' do
  expires -1, :public, :must_revalidate
  haml :login
end  

post '/main_menu' do
  main_menu(params)
end  

get '/main_menu' do
  main_menu(params)
end  

def main_menu(params)
  if params[:username] and params[:password] and params[:username].length > 0 and params[:password].length > 0 
     realm = params[:realm] || "www"
     @param_url = "username=#{params[:username]}&password=#{params[:password]}&realm=#{realm}"
     qbc = QuickBase::Client.init({"username" => params[:username], "password" => params[:password], "org" => realm})
     if qbc.requestSucceeded
        @about = haml :about
        haml :main_menu
     else
        haml :login_error
     end        
  else
    haml :login_error
  end     
end  

get '/list_apps' do
  if params[:username] and params[:password] and params[:username].length > 0 and params[:password].length > 0 
    realm = params[:realm] 
    realm = "www" if realm.nil? or realm.length == 0 
    @main_menu_url = "'/main_menu?username=#{params[:username]}&password=#{params[:password]}&realm=#{params[:realm] || "www"}'"
    begin
      qbc = QuickBase::Client.init({"username" => params[:username], "password" => params[:password], "org" => realm, "cacheSchemas" => true})
      if qbc.requestSucceeded
          @list_of_apps = ""
          qbc.grantedDBs(0,0){|db|
            @list_of_apps << "<li><a href=\"/tables?username=#{params[:username]}&password=#{params[:password]}&realm=#{realm}&app_dbid=#{db.dbinfo.dbid}&app_name=#{db.dbinfo.dbname}\" target=\"_self\">#{db.dbinfo.dbname}</a><li>"
          }
         haml :app_list
      else  
         @qbc_error = qbc.lastError
         haml :quickbase_error
      end
    rescue StandardError => @qbc_error  
      haml :quickbase_error
    end
  else
    redirect '/login'
  end  
end

get '/tables' do
  if params[:username] and params[:password] and params[:username].length > 0 and params[:password].length > 0 
    @apps_url = "'/list_apps?username=#{params[:username]}&password=#{params[:password]}&realm=#{params[:realm] || "www"}'"
    @list_of_tables = "<ul id=\"tables_for_app_#{params[:app_dbid]}\" title=\"Tables: #{params[:app_name]}\" selected=\"true\" >"
    @list_of_reports = ""
    begin
      realm = params[:realm] 
      realm = "www" if realm.nil? or realm.length == 0 
      qbc = QuickBase::Client.init({"username" => params[:username], "password" => params[:password], "org" => realm, "cacheSchemas" => true})
      if qbc.requestSucceeded
        table_dbids = qbc.getTableIDs(params[:app_dbid])
        if qbc.requestSucceeded
            table_dbids.each {|table_dbid|
              qbc.getSchema( table_dbid )
              if qbc.requestSucceeded
                table_name = qbc.getResponseElement( "table/name" )
                @list_of_tables << "<li><a href=\"#reports_for_table_#{table_dbid}\" >#{table_name.text}</a></li>"
                if qbc.queries
                   @list_of_reports << "<ul id=\"reports_for_table_#{table_dbid}\" title=\"Reports: #{params[:app_name]}: #{table_name.text}\" >"
                   qbc.queries.each_element_with_attribute( "id" ){|q|
                      if q.name == "query" 
                         @list_of_reports << "<li><a href=\"/report?dbid=#{table_dbid}&qid=#{q.attributes["id"]}&username=#{params[:username]}&password=#{params[:password]}&realm=#{realm}&app_name=#{params[:app_name]}&app_dbid=#{params[:app_dbid]}&table_name=#{table_name.text}&report_name=#{q.elements["qyname"].text}\"  target=\"_self\" >#{q.elements["qyname"].text}</a></li>"
                      end
                   }
                   @list_of_reports << "</ul>"
                end
              end
            }
          end
      else
        @qbc_error = qbc.lastError
        haml :quickbase_error
      end          
    rescue StandardError => table_access_error
      p table_access_error
    end
    @list_of_tables << "</ul>" 
    haml :table_list
  else
    redirect '/login'
  end  
end

get '/reports' do
  if params[:username] and params[:password] and params[:username].length > 0 and params[:password].length > 0 
    realm = params[:realm] 
    realm = "www" if realm.nil? or realm.length == 0 
    @tables_url = "'/tables?username=#{params[:username]}&password=#{params[:password]}&realm=#{realm}&app_dbid=#{params[:app_dbid]}&app_name=#{params[:app_name]}'"
    @list_of_reports = ""
    begin
      qbc = QuickBase::Client.init({"username" => params[:username], "password" => params[:password], "org" => realm, "cacheSchemas" => true})
      if qbc.requestSucceeded
        qbc.getSchema( params[:table_dbid] )
        if qbc.requestSucceeded
           table_name = qbc.getResponseElement( "table/name" )
           if qbc.queries
              @list_of_reports << "<ul id=\"reports_for_table_#{params[:table_dbid]}\" title=\"Reports: #{table_name}: #{table_name.text}\" selected=\"true\" >"
              qbc.queries.each_element_with_attribute( "id" ){|q|
                 if q.name == "query" 
                   @list_of_reports << "<li><a href=\"/report?dbid=#{params[:table_dbid]}&qid=#{q.attributes["id"]}&username=#{params[:username]}&password=#{params[:password]}&realm=#{realm}&app_name=#{params[:app_name]}&app_dbid=#{params[:app_dbid]}&table_name=#{table_name.text}&report_name=#{q.elements["qyname"].text}\"  target=\"_self\" >#{q.elements["qyname"].text}</a></li>"
                 end
              }
              @list_of_reports << "</ul>"
              haml :report_list
           end
        else
          @qbc_error = qbc.lastError
          haml :quickbase_error
        end
      else
        @qbc_error = qbc.lastError
        haml :quickbase_error
      end
    rescue StandardError => @qbc_error
      haml :quickbase_error
    end
  else
    redirect '/login'
  end  
end  

get '/report' do
  if params[:username] and params[:password] and params[:username].length > 0 and params[:password].length > 0 
    realm = params[:realm] 
    realm = "www" if realm.nil? or realm.length == 0 
    @reports_url = "'/reports?username=#{params[:username]}&password=#{params[:password]}&realm=#{realm}&app_dbid=#{params[:app_dbid]}&app_name=#{params[:app_name]}&table_dbid=#{params[:dbid]}'"
    begin
      qbc = QuickBase::Client.init({"username" => params[:username], "password" => params[:password], "org" => realm, "cacheSchemas" => true})
      if qbc.requestSucceeded
        @record_details = ""
        @records = "<div id=\"report\" title=\"#{params[:table_name]}: #{params[:report_name]}\" class=\"panel\" selected=\"true\">"
        @records << "<table class=\"itable\" width=\"100%\" border=\"0\" cellspacing=\"0\" cellpadding=\"3\"><tr class=\"header\">"
        
        qbc.getSchema(params[:dbid])
        
        clist = qbc.getColumnListForQuery(params[:qid], nil)
        fieldNames = []
        if clist
           clist.split(/\./).each{|c| fieldNames << qbc.lookupFieldNameFromID(c)}
        else
          field_ids = qbc.getFieldIDs(params[:dbid])
          field_ids.each{|field_id| fieldNames << qbc.lookupFieldNameFromID(field_id) unless qbc.isBuiltInField?(field_id)}
        end  
        
        last_index = fieldNames.length-1
        fieldNames.each_index{|i| 
           if i == 0
              @records << "<th class=\"first\">#{fieldNames[i]}</th>"
           elsif i == last_index
              @records << "<th class=\"last\">#{fieldNames[i]}</th>"
           else  
              @records << "<th>#{fieldNames[i]}</th>"
           end  
        }
        
        @records << "</tr>"
        records = qbc.getRecordsArray(params[:dbid], fieldNames, nil, params[:qid])
        alt = false
        record_id = 1
        records.each{|record|
          if alt
            @records << "<tr class=\"alt\">"
          else
            @records << "<tr class=\"reg\">"
          end  
          fieldNames.each_index{|i|
             if i == 0
                @records << "<td class=\"first\"><a href=\"##{record_id}\"> #{record[fieldNames[i]]}</a></td>"
             elsif i == last_index
                @records << "<td class=\"last\"><a href=\"##{record_id}\">#{record[fieldNames[i]]}</a></td>"
             else  
                @records << "<td><a href=\"##{record_id}\">#{record[fieldNames[i]]}</a></td>"
              end  
            alt = !alt  
          }
          @records << "</tr>"
          @record_details << report_record_details(record_id, record, fieldNames, params[:table_name], params[:report_name])
          record_id += 1
        }
        @records << "</table></div>"
        @action_button_text = "Reports: #{params[:table_name]}" 
        haml :report
      else
        @qbc_error = qbc.lastError
        haml :quickbase_error
      end          
    rescue StandardError => @qbc_error
      haml :quickbase_error
    end
  else
    redirect '/login'
  end  
end

def report_record_details(record_id, record, fieldNames, table_name,report_name)
  @report_record_detail_id = record_id
  @report_record_detail_title = "#{table_name}: #{report_name}: Record ##{record_id}"
  @report_record_detail_fields = ""
  fieldNames.each_index{|i|
    @report_record_detail_fields << "<li><label>#{fieldNames[i]}: </label>#{record[fieldNames[i]]}</li>"
  }
  haml :report_record_detail
end  

get '/login_error' do
  haml :login_error
end  


__END__

@@ not_found
%html<
  %head< 
    %title
      QuickBase on iPhone - Page Not Found
    %meta{ :name => "viewport", :content => "width=320; initial-scale=1.0; maximum-scale=1.0; user-scalable=0;" }
    %style{ :type => "text/css", :media => "screen" } 
      @import "/iui/iui.css";
    %script{ :type => "application/x-javascript", :src => "/iui/iui.js"}
  %body<
    .toolbar
      %h1{ :id => "pageTitle" }
      %a{ :id => "backButton", :class => "button", :href => "#" }
    %ul{ :id => "not_found", :title => "Invalid Page" , :selected=> "true" }
      %li 
        Sorry. That page is not valid on this website.

@@ quickbase_error
%html<
  %head< 
    %title
      QuickBase on iPhone - QuickBase Error
    %meta{ :name => "viewport", :content => "width=320; initial-scale=1.0; maximum-scale=1.0; user-scalable=0;" }
    %style{ :type => "text/css", :media => "screen" } 
      @import "/iui/iui.css";
    %script{ :type => "application/x-javascript", :src => "/iui/iui.js"}
  %body<
    .toolbar
      %h1{ :id => "pageTitle" }
      %a{ :id => "backButton", :class => "button", :href => "#" }
    %ul{ :id => "quickbase_error", :title => "Program Error" , :selected=> "true" }
      %li 
        #{@qbc_error}

@@ login
%html<
  %head< 
    %title
      QuickBase on iPhone - Login
    %meta{ :name => "viewport", :content => "width=320; initial-scale=1.0; maximum-scale=1.0; user-scalable=0;" }
    %style{ :type => "text/css", :media => "screen" } 
      @import "/iui/iui.css";
    %script{ :type => "application/x-javascript", :src => "/iui/iui.js"}
  %body<
    .toolbar
      %h1{ :id => "pageTitle" }
    %form{ :id => "login_page", :title => "Login", :class => "panel", :selected => "true", :action => "/main_menu", :method => "post", :target => "_self" }
      %fieldset
        .row
          %label
            Name
          %input{ :type => "text", :name => "username" }
        .row
          %label
            Password
          %input{ :type => "password", :name => "password" }
        .row
          %label
            Realm
          %input{ :type => "text", :name => "realm", :value => "www" }
        %input{ :class => "whiteButton", :type => "submit", :value => "Login"  }

@@ main_menu
%html<
  %head< 
    %title
      QuickBase on iPhone - Main Menu
    %meta{ :name => "viewport", :content => "width=320; initial-scale=1.0; maximum-scale=1.0; user-scalable=0;" }
    %style{ :type => "text/css", :media => "screen" } 
      @import "/iui/iui.css";
      li > label { font-weight: bold; color: #880000; }
    %script{ :type => "application/x-javascript", :src => "/iui/iui.js"}
  %body<
    .toolbar
      %h1{ :id => "pageTitle" } 
      %a{ :id => "backButton", :class => "button", :href => "#" }
      %a{ :id => "actionbutton", :class => "button", :href => "/login", :target => "_self" }
        Login
    %ul{ :id => "main_menu", :title => "Main Menu", :selected => "true" }
      %li
        ! <a href="/list_apps?#{@param_url}" target="_self" >List Applications</a>
      %li
        %a{ :href => "#about"}
          About QuickBase on iPhone
    #{@about}
      
@@ app_list
%html<
  %head< 
    %title
      QuickBase on iPhone - Applications
    %meta{ :name => "viewport", :content => "width=320; initial-scale=1.0; maximum-scale=1.0; user-scalable=0;" }
    %style{ :type => "text/css", :media => "screen" } 
      @import "/iui/iui.css";
    %script{ :type => "application/x-javascript", :src => "/iui/iui.js"}
  %body<
    .toolbar
      %h1{ :id => "pageTitle" } 
      %a{ :id => "backButton", :class => "button", :href => "#" }
      %a{ :id => "actionbutton2", :class => "button", :href => "#{@main_menu_url}", :target => "_self" }
        Main Menu
    %ul{ :id => "apps", :title => "Applications", :selected => "true" }
      #{@list_of_apps}

@@ table_list
%html<
  %head< 
    %title
      QuickBase on iPhone - Tables
    %meta{ :name => "viewport", :content => "width=320; initial-scale=1.0; maximum-scale=1.0; user-scalable=0;" }
    %style{ :type => "text/css", :media => "screen" } 
      @import "/iui/iui.css";
    %script{ :type => "application/x-javascript", :src => "/iui/iui.js"}
  %body<
    .toolbar
      %h1{ :id => "pageTitle" } 
      %a{ :id => "backButton", :class => "button", :href => "#" }
      %a{ :id => "actionbutton", :class => "button", :href => "#{@apps_url}", :target => "_self" }
        Applications
    #{@list_of_tables}
    #{@list_of_reports}

@@ report_list
%html<
  %head< 
    %title
      QuickBase on iPhone - Reports
    %meta{ :name => "viewport", :content => "width=320; initial-scale=1.0; maximum-scale=1.0; user-scalable=0;" }
    %style{ :type => "text/css", :media => "screen" } 
      @import "/iui/iui.css";
    %script{ :type => "application/x-javascript", :src => "/iui/iui.js"}
  %body<
    .toolbar
      %h1{ :id => "pageTitle" } 
      %a{ :id => "backButton", :class => "button", :href => "#" }
      %a{ :id => "actionbutton", :class => "button", :href => "#{@tables_url}", :target => "_self" }
        Tables
    #{@list_of_reports}

@@ report
%html<
  %head< 
    %title
      QuickBase on iPhone - Report
    %meta{ :name => "viewport", :content => "width=320; initial-scale=1.0; maximum-scale=1.0; user-scalable=0;" }
    %style{ :type => "text/css", :media => "screen" } 
      @import "/iui/iui.css";
    %style{ :type => "text/css" }
      \.itable	{ border: 1px solid gray; }
      \.itable tr.header th	{ text-align: left; }
      \.itable tr.alt	{ background-color: #eff7ff; }
      \.itable tr.reg { background-color: #fff; }
      \.itable th	{ background: url(/iui/blue_hd_bg.png) top left repeat-x; border-right: 1px solid grey; }
      \.itable th:last-child	{ border-right: none; }
      \.itable td	{ border-right: 1px solid gray; }
      \.itable tr:first-child { white-space: nowrap; }
      \.itable tr:last-child { border-right: none; }
      li > label { font-weight: bold; color: #880000; }
    %script{ :type => "application/x-javascript", :src => "/iui/iui.js"}
  %body<
    .toolbar
      %h1{ :id => "pageTitle" } 
      %a{ :id => "backButton", :class => "button", :href => "#" }
        Reports
      %a{ :id => "actionbutton", :class => "button", :href => "#{@reports_url}", :target => "_self" }
        #{@action_button_text}
    #{@records}
    #{@record_details}

@@ report_record_detail
%ul{ :id => "#{@report_record_detail_id}", :title => "#{@report_record_detail_title}" }
  #{@report_record_detail_fields}

@@ login_error
%html<
  %head< 
    %title
      QuickBase on iPhone - Login Error
    %meta{ :name => "viewport", :content => "width=320; initial-scale=1.0; maximum-scale=1.0; user-scalable=0;" }
    %style{ :type => "text/css", :media => "screen" } 
      @import "/iui/iui.css";
    %script{ :type => "application/x-javascript", :src => "/iui/iui.js"}
  %body<
    .toolbar
      %h1{ :id => "pageTitle" }
      %a{ :id => "actionbutton", :class => "button", :href => "/login", :target => "_self" }
        Login
    %ul{ :id => "login_error", :title => "Login Error" , :selected=> "true" }
      %li 
        %a{ :href => '/login' } 
          Please enter a valid QuickBase username and password.

@@ about
%ul{ :id => "about", :title => "About QuickBase on iPhone" }
  %li 
    %label<
      Author:
    Gareth Lewis  
  %li 
    %label<
      Programming languages:
    %a{ :href => 'http://www.ruby-lang.org',  :target => "_self" } 
      Ruby, Javascript  
  %li 
    %label<
      UI library:
    %a{ :href => 'http://code.google.com/p/iui',  :target => "_self" } 
      iUI
  %li 
    %label<
      Web application framework:
    %a{ :href => 'http://www.sinatrarb.com',  :target => "_self" } 
      Sinatra
  %li 
    %label<
      QuickBase API library:
    %a{ :href => 'https://rubygems.org/gems/quickbase_client',  :target => "_self" } 
      Ruby SDK
  %li 
    %label<
      HTML rendering:
    %a{ :href => 'http://haml-lang.com',  :target => "_self" } 
      Haml
  %li 
    %label<
      Server platform:
    %a{ :href => 'http://heroku.com',  :target => "_self" } 
      Heroku
