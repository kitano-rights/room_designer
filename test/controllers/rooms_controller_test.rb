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

  test "index should have new room modal with form" do
    get rooms_url
    assert_select "button", text: "新規作成"
    assert_select "dialog form[action=?]", rooms_path do
      assert_select "input[name=?]", "room[name]"
    end
  end

  test "should get show" do
    get room_url(@room)
    assert_response :success
  end

  test "should get new" do
    get new_room_url
    assert_response :success
  end

  test "create should make a room with empty corners and redirect to editor" do
    assert_difference("Room.count") do
      post rooms_url, params: { room: { name: "リビング" } }
    end
    room = Room.order(:id).last
    assert_equal "リビング", room.name
    assert_equal [], room.corners
    assert_redirected_to edit_room_url(room)
  end

  test "create with blank name should re-render index with errors in modal" do
    assert_no_difference("Room.count") do
      post rooms_url, params: { room: { name: "" } }
    end
    assert_response :unprocessable_entity
    # 一覧ページのまま、モーダルが開いた状態でエラーを表示する
    assert_select "table"
    assert_select "[data-modal-open-value=?]", "true"
    assert_select "dialog .text-error"
  end

  test "should get edit" do
    get edit_room_url(@room)
    assert_response :success
  end
end
