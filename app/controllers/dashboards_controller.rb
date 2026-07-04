class DashboardsController < ApplicationController
  # GET /dashboard
  def show
    authorize :dashboard, :show?
    @metrics = DashboardMetrics.new(chart_range: params[:range])
  end
end
