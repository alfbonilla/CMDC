class CmTestsTestsController < ApplicationController
  include CmCommonHelper

  before_filter :find_tests_test, :only => [:edit, :destroy]

  accept_key_auth :edit, :destroy
  helper :cm_tests
  include CmTestsHelper

  def new
    @creating = true

    if request.get?
      @cm_test_id = params[:id]
      @intro_test = CmTest.find_by_id(@cm_test_id)
      @project = @intro_test.project
      @new_type = params[:new_type].to_s
      @cm_tests_test = CmTestsTest.new
      if @new_type == "father"
        @cm_tests_test.child_test_id = @cm_test_id
      else
        @cm_tests_test.cm_test_id = @cm_test_id
      end

      @number_of_test_related = (params[:number_of_tests].to_i + 1) * 10

      #Get Test able to relate based on TYPE-LEVEL conditions
      @level_allowed = params[:test_level].to_i
      @level_type = CmTestType.find(:first, 
        :conditions => ['level=? and project_id in (?,?)', @level_allowed, 0, @project.id])
      
      if @level_type.blank?
        flash[:error] = 'There are no Test for expected level: ' + @level_allowed.to_s +
                        ' customize Test Types if needed'
        redirect_to :controller => 'cm_tests', :action => 'show', :id => @cm_test_id
        return
      end

      # Get all Tests of next level in projects hierarchy
      columns, values = prepare_get_for_projects(CmTest, @project, nil, nil)
      columns << "and type_id = ?"
      values << @level_type.id

      conditions = [columns]
      values.each do |value|
        conditions << value
      end

      @tests_to_add = CmTest.find(:all, :conditions => conditions, :order => "code ASC")

      if @tests_to_add.blank?
        flash[:error] = 'There are no Test to relate with type ' + @level_type.name
        redirect_to :controller => 'cm_tests', :action => 'show', :id => @cm_test_id
        return
      end

      #Remove Tests already related
      case @new_type
      when "child"
        #test has to be related as a father. Relation = Is satisfied by
        @cm_tests_test.relation_type = 2
        already_related = CmTestsTest.find(:all,
          :conditions => ['cm_test_id = ? and relation_type=?', @cm_test_id, 2])
      when "father"
        #test has to be related as a child. Relation = Is satisfied by anyway
        @cm_tests_test.relation_type = 2
        already_related = CmTestsTest.find(:all,
          :conditions => ['child_test_id = ? and relation_type=?', @cm_test_id, 2])
      end
      already_related.each do |to_del|
        case @new_type
        when "child"
          test_to_del = CmTest.find_by_id(to_del.child_test_id)
        when "father"
          test_to_del = CmTest.find_by_id(to_del.cm_test_id)
        end
        @tests_to_add.delete(test_to_del)
      end
      #Remove own Test
      @tests_to_add.delete(@intro_test)
      if @tests_to_add.count == 0
        flash[:error] = 'There are no Tests to relate with type ' + @level_type.name
        redirect_to :controller => 'cm_tests', :action => 'show', :id => @cm_test_id
        return
      end
    end

    if request.post?
      @cm_tests_test = CmTestsTest.new(params[:cm_tests_test])
      @new_type = params[:working_data][:new_type]
      @modified_test = CmTest.find_by_id(@cm_tests_test.cm_test_id)
      @project = @modified_test.project

      @cm_tests_test.created_on = Time.now
      @cm_tests_test.author = User.current

      # Recover working data
      @tests_to_add = params[:working_data][:tests_to_add]

      if @cm_tests_test.save
        flash[:notice] = l(:notice_successful_update)
      else
        flash[:error] = 'Error saving relation between Tests'
      end
      if @new_type == "father"
        redirect_to :controller => 'cm_tests', :action => 'show', :id => @cm_tests_test.child_test_id
      else
        redirect_to :controller => 'cm_tests', :action => 'show', :id => @cm_tests_test.cm_test_id
      end
    end

  rescue ActiveRecord::StatementInvalid => e
    raise e unless /Mysql::Error: Duplicate entry/.match(e)

    flash[:error] = 'There is a relation with Test ' + @cm_tests_test.child_test_id.to_s + ' already created!'
  end

  def edit
    @intro_test=@cm_tests_test.parent_test
    @creating = false

    if request.get?
      @back_id=params[:back_id]
    end
    
    if request.post?
      if @cm_tests_test.update_attributes(params[:cm_tests_test])
        flash[:notice] = l(:notice_successful_update)
        redirect_to(:action => 'show',:controller => "cm_tests", 
            :id =>params[:working_data][:back_id])
      else
        flash[:error] = "Edit not performed!!"
      end
    end
  rescue ActiveRecord::StaleObjectError
    # Optimistic locking exception
     flash.now[:error] = l(:notice_locking_conflict)
  end

  def destroy
    @cm_tests_id = params[:test_id].to_i
    @new_type = params[:new_type]
    # Treat the father of the relation
    @modified_test = CmTest.find_by_id(@cm_tests_test.cm_test_id)
    @project=@modified_test.project_id
    @cm_tests_test.destroy

    Journal.create(:journalized_id => @cm_tests_id, :journalized_type => 'CmTest', :user_id => User.current.id,
                   :notes => 'Deleted relation with ' + params[:child_id])

    if @new_type == "father"
      redirect_to :controller => 'cm_tests', :action => 'show', :project_id => @project, :id => @cm_tests_test.child_test_id
    else
      redirect_to :controller => 'cm_tests', :action => 'show', :project_id => @project, :id => @cm_tests_id
    end
  end

  private

  def find_tests_test
    @cm_tests_test=CmTestsTest.find(params[:id])
  end
end
