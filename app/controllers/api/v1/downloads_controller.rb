class Api::V1::DownloadsController < ApplicationController
  before_action :authenticate_user!
  
  def index
    render json: {items: current_user.downloads.order(created_at: :desc).map(&:to_json)}
  end

  def create
    download = current_user.downloads.build(params.require(:download).permit(:url))      
    if download.save
      download.queue!
      render nothing: true, status: 200
    else
      render json: {error: download.errors.full_messages.join(", ")}, status: 422
    end
  end

  def destroy
    download = current_user.downloads.where(id: params[:id]).first
    if download &&  download.destroy
      render nothing: true, status: 200
    else
      render nothing: true, status: 422
    end
  end

  def cancel
    download = current_user.downloads.where(id: params[:id]).first
    if download &&  download.cancelled!
      render nothing: true, status: 200
    else
      render nothing: true, status: 422
    end
  end

  def queue
    download = current_user.downloads.where(id: params[:id]).first
    if download &&  download.queue!
      render nothing: true, status: 200
    else
      render nothing: true, status: 422
    end
  end
end