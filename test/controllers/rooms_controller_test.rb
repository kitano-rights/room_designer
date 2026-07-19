require "test_helper"

class RoomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @room = rooms(:one)
  end

  test "should get index" do
    get rooms_url
    assert_response :success
  end

  test "index should display room names" do
    get rooms_url
    assert_select "table" do
      assert_select "a", text: @room.name
    end
  end

  test "index should have link to new room" do
    get rooms_url
    assert_select "a[href=?]", new_room_path
  end

  test "should get show" do
    get room_url(@room)
    assert_response :success
  end

  test "should get new" do
    get new_room_url
    assert_response :success
  end

  test "should get edit" do
    get edit_room_url(@room)
    assert_response :success
  end
end
