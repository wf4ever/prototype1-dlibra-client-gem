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

    #describe "#exists?" do
    #	it "should exist" do
    #		workspace.exists?.should == true
    #	end
    #end

    #describe "#metadata_rdf" do
    #	it "should contain some metadata" do
    #		workspace.metadata_rdf.should include("Aggregation")
    #	end
    #end
    #describe "#metadata" do
    #	it "should be of aggregation type" do
    #		workspace.metadata.first_object([workspace.uri, RDF.type]).should == DlibraClient::ORE.Aggregation
    #	end
    #end

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

    describe "#[]" do
      it "should resolve ro1" do
        r = workspace["ro1"]
        r.exists?.should == true
      end
      it "should not resolve ro2" do
        wrong = workspace["ro2"]
        wrong.should == nil
      end
    end
    describe "each" do
      it "should contain ro1" do
        l = []
        for r in workspace
          l << r.uri
        end
        l.size.should == 1
        l[0].to_s.should == ro1.uri.to_s
      end
    end

    describe DlibraClient::ResearchObject do
      describe "#exists?" do
        it "should exist" do
          ro1.exists?.should == true
        end
      end
      describe "#versions" do
        it "should initially be an empty list" do
          ro1.versions.should == []
        end
      end

      describe "#metadata_rdf" do
        it "should contain some metadata" do
          ro1.metadata_rdf.should include("Aggregation")
        end
      end
      describe "#metadata" do
        it "should be of aggregation type" do
          ro1.metadata.first_object([ro1.uri, RDF.type]).should == DlibraClient::ORE.Aggregation
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
          #puts ro1.uri.to_s
          ver1.uri.to_s.should == ro1.uri.to_s + "/ver1"
        #puts "ver1", ver1.uri.to_s
        end
      end

      describe "#[]" do
        it "should resolve ver1" do
          v = ro1["ver1"]
          v.exists?.should == true
        end
        it "should not resolve ver2" do
          wrong = ro1["ver2"]
          wrong.should == nil
        end
      end
      describe "each" do
        it "should contain ver1" do
          l = []
          for r in ro1
            l << r.uri
          end
          l.size.should == 1
          l[0].to_s.should == ver1.uri.to_s
        end
      end

      describe DlibraClient::Version do

        describe "#exists?" do
          it "should exist" do
            ver1.exists?.should == true
          end
        end

        describe "#resources" do
          it "should initially be an empty list" do
            ver1.resources.should == []
          end
        end

        describe "#metadata_rdf" do
          it "should contain some metadata" do
            rdf = ver1.metadata_rdf
            #puts rdf
            rdf.should include("Aggregation")
          end
        end
        describe "#metadata" do
          it "should be of aggregation type" do
            ver1.metadata.first_object([ver1.uri, RDF.type]).should == DlibraClient::ORE.Aggregation
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

        describe "#[]" do
          it "should resolve ver1" do
            v = ver1["resource.txt"]
            v.exists?.should == true
          end
          it "should not resolve ver2" do
            wrong = ver1["notfound.txt"]
            wrong.should == nil
          end
        end
        describe "each" do
          it "should contain resource.txt" do
            l = []
            for r in ver1
              l << r.uri
            end
            l.size.should == 1
            l[0].to_s.should == f1.uri.to_s
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

        describe "#clone" do
          ver2 =
          it "should create a second version" do
            ver2 = ver1.clone("ver2")
            ver2.uri.to_s.should == ro1.uri.to_s + "/ver2"
          end
          it "should contain a copy of the old resource" do
            ver2.resources.size.should == 1
            ver2.resources[0].uri.to_s.should == ver2.uri.to_s + "/resource.txt"
          end
        end

        describe DlibraClient::Resource do

          describe "#exists?" do
            it "should exist" do
              f1.exists?.should == true
            end
          end

          describe "#content" do
            it "should return the resource content" do
              f1.content.should == "Hello world!\nA simple resource.\n"
            end
            it "should be downloadable to a file" do
              file = Tempfile.new("dlibra-test")
              begin
                f1.content(file)
                file.seek(0)
                file.read().should == "Hello world!\nA simple resource.\n"

              ensure
              file.unlink
              file.close
              end
            end
          end

          describe "#metadata" do
            metadata=
            it "should retrieve the metadata graph" do
              metadata = f1.metadata
            end
            it "should have the right mime type" do
              metadata.first_value([f1.uri, DlibraClient::DCTERMS.type]).should == "text/plain"
            end
            it "should have correct size" do
              metadata.first_value([f1.uri, DlibraClient::DCTERMS.extent]).should == "32"
            end
            it "should have a modified date from this year" do
              year = DateTime.now.year.to_s
              metadata.first_value([f1.uri, DlibraClient::DCTERMS.modified]).should include(year)
            end
          end

          describe "#metadata_rdf" do
            rdf=
            it "should retrieve the RDF" do
              rdf = f1.metadata_rdf
            end
            it "should include the mime type" do
              rdf.should include("text/plain")
            end
            it "should include the extent" do
              rdf.should include(">32<")
            end
          end

          #describe "#metadata=" do
          #	it "should allow additional annotations" do
          #		metadata = f1.metadata
          #		metadata << [f1.uri, DlibraClient::DCTERMS.description, "An interesting file"]
          #		f1.metadata = metadata
          #		f1.metadata_rdf.should include("interesting file")
          #		f1.metadata.first_value([f1.uri, DlibraClient::DCTERMS.description]).should == "An interesting file"
          #	end
          #end
          #describe "#metadata_rdf=" do
          #	it "should allow additional annotations" do
          #		f1.metadata_rdf = f1.metadata_rdf.sub("n interesting", " boring")
          #		f1.metadata_rdf.should include("boring file")
          #		f1.metadata.first_value([f1.uri, DlibraClient::DCTERMS.description]).should == "An boring file"
          #	end
          #end

          describe "#content_type" do
            it "should be text/plain" do
              f1.content_type.should == "text/plain"
            end
          end
          describe "#size" do
            it "should be 32" do
              f1.size.should == 32
            end
          end
          describe "#modified" do
            it "should be from this year" do
              f1.modified.year.should == DateTime.now.year
            end
          end

          describe "#content=" do
            it "should replace the file content" do
              before = f1.modified
              f1.content = "Different content"
              f1.content.should == "Different content"
              f1.size.should == 17
              f1.modified.should > before
            end
          end

          describe "#delete" do
            it "should delete the resource" do
              ver1.resources.size.should == 1
              f1.delete!
              ver1.resources.size.should == 0
            end
          end
        end

        describe "#exists?" do
          it "should no longer exist" do
            f1.exists?.should == false
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
            ro1.versions.size.should == 2
            ver1.delete!
            ver2 = ro1.versions[0]
            ver2.delete!
            ro1.versions.size.should == 0
          end
        end

        describe "#exists?" do
          it "should no longer exist" do
            ver1.exists?.should == false
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

      describe "#exists?" do
        it "should no longer exist" do
          ro1.exists?.should == false
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

  #describe "#exists?" do
  #	it "should no longer exist" do
  #		workspace.exists?.should == false
  #	end
  #end

  end

end
