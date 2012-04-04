require 'test_helper'

class TransferRequestTest < ActiveSupport::TestCase
  context 'TransferRequest' do
    context 'when starting the request' do
      setup do
        @source = LibraryTube.create!.tap { |tube| tube.aliquots.create!(:sample => Factory(:sample)) }
        Factory(:tag).tag!(@source)

        @destination = LibraryTube.create!

        @transfer_request = TransferRequest.create!(:asset => @source, :target_asset => @destination)
      end

      should 'duplicate the aliquots' do
        expected_aliquots = @source.aliquots.map { |a| [ a.sample_id, a.tag_id ] }
        target_aliquots   = @destination.aliquots.map { |a| [ a.sample_id, a.tag_id ] }
        assert_equal(expected_aliquots, target_aliquots)
      end

      should 'have a request type' do
        assert @transfer_request.request_type == RequestType.find_by_key('transfer')
      end

    end

    should 'not permit transfers to the same asset' do
      asset = Factory(:sample_tube)
      assert_raises(ActiveRecord::RecordInvalid) { TransferRequest.create!(:asset => asset, :target_asset => asset) }
      assert_raises(ActiveRecord::RecordInvalid) { RequestType.transfer.new(:asset => asset, :target_asset => asset) }
    end

    context 'when using the constuctor' do
      setup do
        @source = LibraryTube.create!.tap { |tube| tube.aliquots.create!(:sample => Factory(:sample)) }
        Factory(:tag).tag!(@source)

        @destination = LibraryTube.create!

        @transfer_request = RequestType.transfer.new(:asset => @source, :target_asset => @destination)
      end

      should 'duplicate the aliquots' do
        expected_aliquots = @source.aliquots.map { |a| [ a.sample_id, a.tag_id ] }
        target_aliquots   = @destination.aliquots.map { |a| [ a.sample_id, a.tag_id ] }
        assert_equal(expected_aliquots, target_aliquots)
      end

      should 'have the correct attributes' do
        assert @transfer_request.request_type == RequestType.find_by_key('transfer')
        assert @transfer_request.sti_type == 'TransferRequest'
        assert @transfer_request.state == 'pending'
        assert @transfer_request.asset_id == @source.id
        assert @transfer_request.target_asset_id == @destination.id
      end

    end
  end
end
