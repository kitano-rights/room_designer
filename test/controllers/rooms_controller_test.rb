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

  test "show should display room name and navigation links" do
    get room_url(@room)
    assert_select "h2", text: @room.name
    assert_select "a[href=?]", rooms_path, text: "一覧へ戻る"
    assert_select "a[href=?]", edit_room_path(@room), text: "エディターへ"
  end

  test "show should display palette area" do
    get room_url(@room)
    assert_select "#palette"
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

  test "index should have edit modal with form for each room" do
    get rooms_url
    assert_select "button[aria-label=?]", "部屋名を編集", count: Room.count
    assert_select "dialog form[action=?]", room_path(@room) do
      assert_select "input[name=?]", "room[name]"
    end
  end

  test "index should have delete confirmation modal for each room" do
    get rooms_url
    assert_select "button[aria-label=?]", "部屋を削除", count: Room.count
    assert_select "dialog form[action=?]", room_path(@room) do
      assert_select "input[name=_method][value=delete]"
      assert_select "button", text: "削除する"
    end
  end

  test "update should change room name and redirect to index" do
    patch room_url(@room), params: { room: { name: "書斎" } }
    assert_redirected_to rooms_path
    assert_equal "書斎", @room.reload.name
  end

  test "update with blank name should re-render index with errors in edit modal" do
    patch room_url(@room), params: { room: { name: "" } }
    assert_response :unprocessable_entity
    assert_equal "リビング", @room.reload.name
    # 該当行の編集モーダルだけが開いた状態で再描画される
    assert_select "[data-modal-open-value=?]", "true", count: 1
    assert_select "dialog .text-error"
  end

  test "destroy should delete room and redirect to index" do
    assert_difference("Room.count", -1) do
      delete room_url(@room)
    end
    assert_redirected_to rooms_path
  end
end
