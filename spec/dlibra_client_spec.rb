
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'uuidtools'
require 'base64'


describe DlibraClient::Workspace do
    
    describe "#initialize" do
        it "should be constructed with a valid URI, workspace ID and password" do
            workspace = DlibraClient::Workspace.new("http://example.com/wf4ever/", "fred", "fish")
            workspace.uri.to_s.should == "http://example.com/wf4ever/workspaces/fred"
        end
    end

    describe "#create" do
        workspace =    
        workspace_id = "test-" + Base64.urlsafe_encode64(UUIDTools::UUID.random_create().raw)[0,22]
        it "should create workspace" do
            workspace = DlibraClient::Workspace.create(BASE, workspace_id, "uncle", ADMIN, ADMIN_PW)
            workspace.uri.to_s.should == BASE + "workspaces/" + workspace_id 
        end
        it "should detect conflicting names" do
            lambda {
                DlibraClient::Workspace.create(BASE, workspace_id, "uncle", ADMIN, ADMIN_PW)
            }.should raise_error(DlibraClient::WorkspaceCreationError)
        end
        describe "#research_objects" do
            it "should be initially be an empty list" do
                    workspace.research_objects.should == []
            end
        end
        ro1 = 
        describe "#create_research_object" do
            it "should make a new research object" do
                ro1 = workspace.create_research_object("ro1")
                ro1.uri.to_s.should == workspace.uri.to_s + "/ROs/ro1"
            end
        end
        describe "#research_objects" do
            it "should now contain the new ro" do
                ros = workspace.research_objects
                ros.size.should == 1
                ro = ros[0]
                ro.uri.to_s.should == workspace.uri.to_s + "/ROs/ro1"
            end
        end
        describe DlibraClient::ResearchObject do
            describe "#delete" do
                it "should delete the RO" do
                    workspace.research_objects.size.should == 1
                    ro1.delete!
                    workspace.research_objects.size.should == 0        
                end    
            end 
        end
        describe "#delete" do
            it "should delete the workspace" do
                workspace.delete!(ADMIN, ADMIN_PW)
                lambda {
                    workspace.research_objects
                }.should raise_error
            end    
        end 


    end
    
end
