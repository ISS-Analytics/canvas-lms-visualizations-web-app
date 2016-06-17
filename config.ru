# \ -s puma

Dir.glob('./{controllers,services,values,forms}/*.rb')
  .each do |file|
  require file
end
run CanvasVisualizationApp
