require 'sinatra'
require 'QuickBaseClient'
require 'haml'

get '/' do
  haml :login
end  

get '/login' do
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

get '/report' do
  if params[:username] and params[:password] and params[:username].length > 0 and params[:password].length > 0 
    realm = params[:realm] 
    realm = "www" if realm.nil? or realm.length == 0 
    @tables_url = "'/tables?username=#{params[:username]}&password=#{params[:password]}&realm=#{realm}&app_dbid=#{params[:app_dbid]}&app_name=#{params[:app_name]}'"
    begin
      qbc = QuickBase::Client.init({"username" => params[:username], "password" => params[:password], "org" => realm, "cacheSchemas" => true})
      if qbc.requestSucceeded
        @records = "<div id=\"report\" title=\"#{params[:table_name]}: #{params[:report_name]}\" class=\"panel\" selected=\"true\">"
        @records << "<table class=\"itable\" width=\"100%\" border=\"0\" cellspacing=\"0\" cellpadding=\"3\"><tr class=\"header\">"
        
        qbc.getSchema(params[:dbid])
        
        clist = qbc.getColumnListForQuery(params[:qid], nil)
        fieldNames = []
        if clist
           clist.split(/\./).each{|c| fieldNames << qbc.lookupFieldNameFromID(c)}
        else
          fieldNames = qbc.getFieldNames(params[:qid])
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
        records.each{|record|
          if alt
            @records << "<tr class=\"alt\">"
          else
            @records << "<tr class=\"reg\">"
          end  
          fieldNames.each_index{|i|
             if i == 0
                @records << "<td class=\"first\">#{record[fieldNames[i]]}</td>"
             elsif i == last_index
                @records << "<td class=\"last\">#{record[fieldNames[i]]}</td>"
             else  
                @records << "<td>#{record[fieldNames[i]]}</td>"
              end  
            alt = !alt  
          }
          @records << "</tr>"
        }
        @records << "</table></div>"
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

get '/login_error' do
  haml :login_error
end  


__END__

@@ quickbase_error
%html<
  %head< 
    %title
      QuickBase on iPhone
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
      QuickBase on iPhone
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
      QuickBase on iPhone
    %meta{ :name => "viewport", :content => "width=320; initial-scale=1.0; maximum-scale=1.0; user-scalable=0;" }
    %style{ :type => "text/css", :media => "screen" } 
      @import "/iui/iui.css";
    %script{ :type => "application/x-javascript", :src => "/iui/iui.js"}
  %body<
    .toolbar
      %h1{ :id => "pageTitle" } 
    %ul{ :id => "main_menu", :title => "Main Menu", :selected => "true" }
      %li
        ! <a href="/list_apps?#{@param_url}" target="_self" >List Applications</a>

@@ app_list
%html<
  %head< 
    %title
      QuickBase on iPhone
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
    %ul{ :id => "apps", :title => "Apps", :selected => "true" }
      #{@list_of_apps}

@@ table_list
%html<
  %head< 
    %title
      QuickBase on iPhone
    %meta{ :name => "viewport", :content => "width=320; initial-scale=1.0; maximum-scale=1.0; user-scalable=0;" }
    %style{ :type => "text/css", :media => "screen" } 
      @import "/iui/iui.css";
    %script{ :type => "application/x-javascript", :src => "/iui/iui.js"}
  %body<
    .toolbar
      %h1{ :id => "pageTitle" } 
      %a{ :id => "backButton", :class => "button", :href => "#" }
      %a{ :id => "actionbutton", :class => "button", :href => "#{@apps_url}", :target => "_self" }
        Apps
    #{@list_of_tables}
    #{@list_of_reports}

@@ report
%html<
  %head< 
    %title
      QuickBase on iPhone
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
    %script{ :type => "application/x-javascript", :src => "/iui/iui.js"}
  %body<
    .toolbar
      %h1{ :id => "pageTitle" } 
      %a{ :id => "backButton", :class => "button", :href => "#" }
        Reports
      %a{ :id => "actionbutton", :class => "button", :href => "#{@tables_url}", :target => "_self" }
        Tables
    #{@records}

@@ login_error
%html<
  %head< 
    %title
      QuickBase on iPhone
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
