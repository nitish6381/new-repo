require 'rest-client'
require 'json'
require 'active_record'
headers = {
  'propel-admin-backend-version' => 'v1',
  'Authorization' => Figaro.env.propel_admin_backend_server_private_key,
  'propel-admin-backend-tenant-id' => 'Propel',
  'Content-Type' => 'application/json'
}
BATCH_SIZE = 100 # Adjust the batch size as needed
SLEEP_INTERVAL = 0.5 # Adjust the delay between API calls as needed
def update_client_user(client_user, headers)
  if client_user.department_id.present?
    department = Department.find_by(id: client_user.department_id)
    if department.present?
      param = {
        name: department.name,
        client_id: department.client_id
      }
      response = RestClient.post('https://api.zaggle.in/api/v1/propel/admin-settings/client/department/search', param.to_json, headers) rescue nil
      if response.present?
        response_body = JSON.parse(response.body) rescue nil
        if response_body.present? && response_body['data'].present?
          data = response_body['data']
          dep_id = data.first['id'] if data.is_a?(Array) && data.first.present?
          if dep_id.present?
            ActiveRecord::Base.connection.disable_referential_integrity do
              if client_user.update(department_id: dep_id)
                puts "Updated client_user #{client_user.id} with new department_id #{dep_id}"
              else
                puts "Failed to update client_user #{client_user.id}"
              end
            end
          else
            puts "No valid department_id found in the response for client_user #{client_user.id}"
          end
        else
          puts "Invalid response data for client_user #{client_user.id}: #{response_body}"
        end
      else
        puts "No response or invalid response for client_user #{client_user.id}"
      end
    else
      puts "Department not found for client_user #{client_user.id} with department_id #{client_user.department_id}"
    end
  else
    puts "No department_id present for client_user #{client_user.id}"
  end
rescue => e
  puts "An error occurred for client_user #{client_user.id}: #{e.message}"
end
propel_client_ids = Client.propel_clients('active').pluck(:id)
EmployeeUser.where(client_id: propel_client_ids).find_in_batches(batch_size: BATCH_SIZE) do |batch|
  batch.each do |client_user|
    update_client_user(client_user, headers)
    sleep(SLEEP_INTERVAL) # Rate limiting
  end
end
