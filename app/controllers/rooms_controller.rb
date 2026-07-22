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
  end

  def update
    @room = Room.find(params[:id])
    if @room.update(room_params)
      redirect_to rooms_path
    else
      # 一覧に留まり、エラーを保持した @room で該当行の編集モーダルを開き直す
      @rooms = Room.all
      render :index, status: :unprocessable_entity
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
end
