ActionController::Routing::Routes.draw do |map|

  map.connect 'cmdc/index', :controller => 'cm_commons', :action => 'index',
              :conditions => {:method => [:get]}


  map.connect ':controller/:action/:id' 

end