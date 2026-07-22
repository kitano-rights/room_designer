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

  test "show should render room shape and furnitures in svg" do
    get room_url(@room)
    assert_select "#palette svg polygon"
    assert_select "#palette svg g.furniture", count: @room.furnitures.count
  end

  test "show with fixed corners should render depth lines" do
    @room.update!(corners: Room::FIXED_CORNERS)
    get room_url(@room)
    # 奥行き線3本 + 巾木の上端線2本
    assert_select "#palette svg line",
                  count: Room::FIXED_DEPTH_LINES.size + Room::FIXED_BASEBOARD_POLYGONS.size
  end

  test "show with fixed corners should render baseboards" do
    @room.update!(corners: Room::FIXED_CORNERS)
    get room_url(@room)
    assert_select "#palette svg polygon[fill=?]", "#f8fafc", count: Room::FIXED_BASEBOARD_POLYGONS.size
  end

  test "show without corners should display placeholder message" do
    @room.update!(corners: [])
    get room_url(@room)
    assert_select "#palette svg", count: 0
    assert_select "#palette p", text: /部屋の形がまだありません/
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

  test "edit should display editor with room data and navigation links" do
    get edit_room_url(@room)
    assert_select "[data-controller=room-editor]"
    assert_select "[data-room-editor-corners-value]"
    assert_select "[data-room-editor-furnitures-value]"
    assert_select "a[href=?]", rooms_path, text: "一覧へ戻る"
    assert_select "a[href=?]", room_path(@room), text: "俯瞰へ"
    assert_select "button[data-kind]", count: Furniture::KIND_SPECS.size
    assert_select "button", text: "保存"
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

  test "update with json should save corners and replace furnitures" do
    assert_equal 1, @room.furnitures.count
    patch room_url(@room), params: {
      room: {
        corners: [ [ 0, 0 ], [ 4000, 0 ], [ 4000, 3000 ], [ 0, 3000 ] ],
        furnitures: [
          { kind: "sofa", pos_x: 1000, pos_y: 800, rotation: 90 },
          { kind: "chair", pos_x: 2000, pos_y: 1500, rotation: 45 }
        ]
      }
    }, as: :json
    assert_response :no_content

    @room.reload
    assert_equal [ [ 0, 0 ], [ 4000, 0 ], [ 4000, 3000 ], [ 0, 3000 ] ], @room.corners
    assert_equal %w[sofa chair], @room.furnitures.order(:id).pluck(:kind)
    sofa = @room.furnitures.order(:id).first
    assert_equal [ 1000.0, 800.0, 90.0 ], [ sofa.pos_x, sofa.pos_y, sofa.rotation ]
  end

  test "update with json should save wall and floor colors" do
    patch room_url(@room), params: {
      room: { corners: @room.corners, furnitures: [], wall_color: "#ffffff", floor_color: "#ffffff" }
    }, as: :json
    assert_response :no_content

    @room.reload
    assert_equal "#ffffff", @room.wall_color
    assert_equal "#ffffff", @room.floor_color
  end

  test "update with json should save wall and floor texture keys" do
    patch room_url(@room), params: {
      room: {
        corners: @room.corners, furnitures: [],
        wall_color: "wallpaper_fabric_white", floor_color: "flooring_wood_natural"
      }
    }, as: :json
    assert_response :no_content

    @room.reload
    assert_equal "wallpaper_fabric_white", @room.wall_color
    assert_equal "flooring_wood_natural", @room.floor_color
  end

  test "update with json invalid color should return 422" do
    patch room_url(@room), params: {
      room: { corners: @room.corners, furnitures: [], wall_color: "#123456" }
    }, as: :json
    assert_response :unprocessable_entity
    assert_equal "#ffffff", @room.reload.wall_color
  end

  test "update with json and no furnitures should clear existing furnitures" do
    patch room_url(@room), params: {
      room: { corners: [ [ 0, 0 ], [ 2000, 0 ], [ 2000, 2000 ] ], furnitures: [] }
    }, as: :json
    assert_response :no_content
    assert_equal 0, @room.reload.furnitures.count
  end

  test "update with json invalid furniture kind should return 422 and keep existing data" do
    original_corners = @room.corners
    patch room_url(@room), params: {
      room: {
        corners: [ [ 0, 0 ], [ 1000, 0 ], [ 1000, 1000 ] ],
        furnitures: [ { kind: "table", pos_x: 0, pos_y: 0, rotation: 0 } ]
      }
    }, as: :json
    assert_response :unprocessable_entity

    @room.reload
    assert_equal original_corners, @room.corners
    assert_equal 1, @room.furnitures.count
  end

  test "update with json invalid corners format should return 422" do
    patch room_url(@room), params: {
      room: { corners: [ [ 0 ], [ 1000, 0 ] ], furnitures: [] }
    }, as: :json
    assert_response :unprocessable_entity
  end

  test "destroy should delete room and redirect to index" do
    assert_difference("Room.count", -1) do
      delete room_url(@room)
    end
    assert_redirected_to rooms_path
  end
end
