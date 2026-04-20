module Whatsapp::EvolutionGoHandlers::FileExtensions
  SUPPORTED_FILE_EXTENSIONS = {
    image: %w[jpg jpeg png gif webp],
    video: %w[mp4 avi mov mkv],
    audio: %w[mp3 ogg wav m4a],
    document: %w[pdf doc docx xls xlsx ppt pptx txt]
  }.freeze

  private

  def supported_file_type?(filename)
    return true unless filename

    extension = File.extname(filename).downcase.delete('.')
    SUPPORTED_FILE_EXTENSIONS.values.flatten.include?(extension)
  end

  def get_file_type_from_extension(filename)
    return :file unless filename

    extension = File.extname(filename).downcase.delete('.')

    SUPPORTED_FILE_EXTENSIONS.each do |type, extensions|
      return type if extensions.include?(extension)
    end

    :file
  end
end
