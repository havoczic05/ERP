require 'rails_helper'

RSpec.describe 'Sidebar brand', type: :request do
  let(:user) { create(:user, :administrador) }

  before { login_as(user) }

  it 'shows the company name "HGS ERP" in the sidebar brand' do
    get clients_path
    expect(response.body).to match(%r{class="sidebar-brand__name">\s*HGS ERP\s*</span>})
  end

  it 'renders the brand logo mark' do
    get clients_path
    expect(response.body).to include('sidebar-brand__mark')
  end
end
