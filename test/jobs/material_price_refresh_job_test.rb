require "test_helper"
require "ostruct"

class MaterialPriceRefreshJobTest < ActiveSupport::TestCase
  def setup
    ENV["BIGBOX_API_KEY"] = "test_key"
    @job = MaterialPriceRefreshJob.new
  end

  def teardown
    ENV.delete("BIGBOX_API_KEY")
  end

  test "raises when BIGBOX_API_KEY missing" do
    ENV.delete("BIGBOX_API_KEY")
    assert_raises(RuntimeError, /BIGBOX_API_KEY/) { @job.perform }
  end

  test "raises when transient ratio exceeds budget" do
    @job.stub :start_collection, nil do
      @job.stub :wait_for_completion, nil do
        bad_results = Array.new(60) { OpenStruct.new(status: "transient") } +
                      Array.new(40) { OpenStruct.new(status: "loaded") }
        BigboxCollectionService.stub :ingest_results, bad_results do
          err = assert_raises(RuntimeError) { @job.perform }
          assert_match(/transient failure ratio/, err.message)
        end
      end
    end
  end

  test "runs sync when transient ratio is under budget" do
    @job.stub :start_collection, nil do
      @job.stub :wait_for_completion, nil do
        ok_results = Array.new(20) { OpenStruct.new(status: "transient") } +
                     Array.new(80) { OpenStruct.new(status: "loaded") }
        BigboxCollectionService.stub :ingest_results, ok_results do
          sync_called = false
          fake_sync = lambda do
            sync_called = true
            []
          end
          MaterialPriceSyncService.stub :sync, fake_sync do
            @job.perform
          end
          assert sync_called, "expected MaterialPriceSyncService.sync to be called"
        end
      end
    end
  end
end
