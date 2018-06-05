
unless Rails.env.test?
  ProjectManager.create! name: 'Unallocated'
end
