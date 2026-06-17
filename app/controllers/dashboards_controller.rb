class DashboardsController < ApplicationController
  # GET /dashboard
  def show
    authorize :dashboard, :show?
    @metrics = DashboardMetrics.new
  end
end
