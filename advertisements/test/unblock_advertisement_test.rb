require_relative 'test_helper'

module Advertisements
  class UnblockAdvertisementTest < ActiveSupport::TestCase
    include TestPlumbing

    test 'unblock advertisement' do
      advertisement_id = SecureRandom.random_number
      author_id = SecureRandom.random_number
      content = "Content: #{SecureRandom.hex}"
      suspend_reason = "Reason: #{SecureRandom.hex}"
      stream = "Advertisement$#{advertisement_id}"
      time_when_published = Time.now
      travel_in_time_to(time_when_published)
      original_due_date = time_when_published + FakeDueDatePolicy::FAKE_VALID_FOR_SECONDS
      arrange(
        PublishAdvertisement.new(advertisement_id, author_id, content),
        SuspendAdvertisement.new(advertisement_id, suspend_reason)
      )
      suspended_for = 120
      travel_in_time_to(time_when_published + suspended_for)

      assert_events(
          stream,
          AdvertisementUnblocked.new(
            data: {
              advertisement_id: advertisement_id,
              due_date: original_due_date + suspended_for
            }
          )
      ) do
        act(UnblockAdvertisement.new(advertisement_id))
      end
    end

    test "draft can't be unblocked" do
      advertisement_id = SecureRandom.random_number

      error = assert_raises(Advertisement::UnexpectedStateTransition) do
        act(UnblockAdvertisement.new(advertisement_id))
      end
      assert_equal "Unblock allowed only from [suspended], but was [draft]", error.message
    end

    test "advertisement can't be unblocked if on hold" do
      advertisement_id = SecureRandom.random_number
      author_id = SecureRandom.random_number
      content = "Content: #{SecureRandom.hex}"
      arrange(
        PublishAdvertisement.new(advertisement_id, author_id, content),
        PutAdvertisementOnHold.new(advertisement_id, author_id)
      )

      error = assert_raises(Advertisement::UnexpectedStateTransition) do
        act(UnblockAdvertisement.new(advertisement_id))
      end
      assert_equal "Unblock allowed only from [suspended], but was [on_hold]", error.message
    end

    test "advertisement can't be unblocked if expired" do
      advertisement_id = SecureRandom.random_number
      author_id = SecureRandom.random_number
      content = "Content: #{SecureRandom.hex}"
      arrange(
        PublishAdvertisement.new(advertisement_id, author_id, content),
        ExpireAdvertisement.new(advertisement_id)
      )

      error = assert_raises(Advertisement::UnexpectedStateTransition) do
        act(UnblockAdvertisement.new(advertisement_id))
      end
      assert_equal "Unblock allowed only from [suspended], but was [expired]", error.message
    end

    test "advertisement can't be unblocked if published" do
      advertisement_id = SecureRandom.random_number
      author_id = SecureRandom.random_number
      content = "Content: #{SecureRandom.hex}"
      arrange(
        PublishAdvertisement.new(advertisement_id, author_id, content)
      )

      error = assert_raises(Advertisement::UnexpectedStateTransition) do
        act(UnblockAdvertisement.new(advertisement_id))
      end
      assert_equal "Unblock allowed only from [suspended], but was [published]", error.message
    end
  end
end
