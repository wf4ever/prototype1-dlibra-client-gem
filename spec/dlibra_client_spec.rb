require File.join(File.dirname(__FILE__), 'spec_helper')
require 'uuidtools'
require 'base64'
require 'tempfile'
require 'zip/zipfilesystem'

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
			}.should raise_error(DlibraClient::CreationError)
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
			describe "#versions" do
				it "should initially be an empty list" do
					ro1.versions.should == []
				end
			end
			describe "#add_version" do
				it "should create a new version" do
					version = ro1.create_version("ver1")
					version.uri.to_s.should == ro1.uri.to_s + "/ver1"
				end
			end
			ver1 =
			describe "#versions" do
				it "should now contain the new version" do
					ro1.versions.size.should == 1
					ver1 = ro1.versions[0]
					ver1.uri.to_s.should == ro1.uri.to_s + "/ver1"
				end
			end
			describe DlibraClient::Version do
				describe "#resources" do
					it "should initially be an empty list" do
						ver1.resources.should == []
					end
				end
				f1 =
				describe "#upload_resource" do
					it "should upload the resource" do
						f1 = ver1.upload_resource("resource.txt", "text/plain",
						"Hello world!\nA simple resource.\n")
						f1.uri.to_s.should == ver1.uri.to_s + "/resource.txt"
					end
				end
				describe "#resources" do
					it "should now contain the new resource" do
						ver1.resources.size.should == 1
						f1 = ver1.resources[0]
						f1.uri.to_s.should == ver1.uri.to_s + "/resource.txt"
					end
				end

				manifest_with_resource=
				describe "#manifest_rdf" do
					it "should be RDF/XML" do
						ver1.manifest_rdf.should include("rdf:Description")
					end
					it "should include resource.txt" do
						ver1.manifest_rdf.should include("resource.txt")
						manifest_with_resource = ver1.manifest_rdf
					end
				end
				describe "#manifest" do
					it "should be an RDF::Graph" do
						manifest = ver1.manifest
						aggregates = []
						manifest.query([nil, DlibraClient::ORE.aggregates, nil]) do |s,p,resource|
							aggregates << resource.to_s
						end
						aggregates.should include(f1.uri.to_s)
					end
				end

				describe "#to_zip" do
					it "should be downloadable as a string" do
						zip = ver1.to_zip
						zip.length.should be > 512
					end
					
					it "should download a zip file of manifest and all resources" do
						file = Tempfile.new("dlibra-test")
						begin
							ver1.to_zip(file)
							file.seek(0)
							Zip::ZipFile.open(file) do |zipfile|
								zipfile.file.read("manifest.rdf").should include("resource.txt")
								zipfile.file.read("resource.txt").should == "Hello world!\nA simple resource.\n"
							end
						ensure
							file.unlink
							file.close
						end
					end
				end

				describe DlibraClient::Resource do
					describe "#delete" do
						it "should delete the resource" do
							ver1.resources.size.should == 1
							f1.delete!
							ver1.resources.size.should == 0
						end
					end
				end

				describe "#manifest=" do
					it "should upload the new manifest graph" do
						graph = ver1.manifest
						graph.delete( [ver1.uri, DlibraClient::DCTERMS.title] )
						graph << [ ver1.uri, DlibraClient::DCTERMS.title, "A good example" ]
						ver1.manifest = graph
						ver1.manifest_rdf.should include("good example")
						title = ver1.manifest.first_value([ver1.uri, DlibraClient::DCTERMS.title])
						title.should == "A good example"
					end
				end

				describe "#manifest_rdf=" do
					it "should upload the new manifest, but ignore removed ROs" do
						ver1.manifest_rdf = manifest_with_resource
						ver1.manifest_rdf.should_not include("resource.txt")
						ver1.manifest_rdf.should_not include("good example")
					end
				end

				describe "#delete" do
					it "should delete the version" do
						ro1.versions.size.should == 1
						ver1.delete!
						ro1.versions.size.should == 0
					end
				end
			end

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
