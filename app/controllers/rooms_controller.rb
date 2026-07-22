class RoomsController < ApplicationController
  def index
    @rooms = Room.all
    # 新規作成モーダル用（name にはモデルのデフォルト値が入る）
    @room = Room.new
  end

  def show
    @room = Room.find(params[:id])
  end

  def new
    @room = Room.new
  end

  def create
    @room = Room.new(room_params)
    if @room.save
      redirect_to edit_room_path(@room)
    else
      # 一覧に留まり、エラーを保持した @room でモーダルを開き直す
      @rooms = Room.all
      render :index, status: :unprocessable_entity
    end
  end

  def edit
    @room = Room.find(params[:id])
  end

  def update
    @room = Room.find(params[:id])

    respond_to do |format|
      # エディターからのレイアウト保存
      format.json { update_layout }

      # 一覧の部屋名編集モーダルからの更新
      format.html do
        if @room.update(room_params)
          redirect_to rooms_path
        else
          # 一覧に留まり、エラーを保持した @room で該当行の編集モーダルを開き直す
          @rooms = Room.all
          render :index, status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    Room.find(params[:id]).destroy
    redirect_to rooms_path, status: :see_other
  end

  private

  def room_params
    params.expect(room: [ :name ])
  end

  # エディターの状態（部屋の形と家具）を1リクエストでまとめて保存する
  # 家具は既存を全て消して送信された内容で入れ直す
  def update_layout
    Room.transaction do
      @room.update!(corners: corners_param, **color_params)
      @room.furnitures.destroy_all
      furnitures_param.each { |attrs| @room.furnitures.create!(attrs) }
    end
    head :no_content
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.join("、") }, status: :unprocessable_entity
  rescue ArgumentError, TypeError, NoMethodError
    render json: { error: "パラメータの形式が不正です" }, status: :unprocessable_entity
  end

  # corners は [[x, y], ...] 形式のみ受け付け、数値へ正規化する
  def corners_param
    Array(params.dig(:room, :corners)).map do |point|
      raise ArgumentError unless point.is_a?(Array) && point.size == 2
      point.map { |value| Float(value) }
    end
  end

  # 壁紙・フローリングの色（未送信ならキーごと省き、既存値を保つ）
  def color_params
    params.fetch(:room, {}).permit(:wall_color, :floor_color).to_h.symbolize_keys
  end

  def furnitures_param
    Array(params.dig(:room, :furnitures)).map do |furniture|
      furniture.permit(:kind, :pos_x, :pos_y, :rotation)
    end
  end
end
