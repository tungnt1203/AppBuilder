module ProjectsHelper
  # Ideas to start from on the home page: a name and a request the agent can build.
  SUGGESTIONS = [
    { name: "Tiệm nail Hoa", request: "Khách đặt lịch làm nail online, chọn dịch vụ và thợ. Chủ tiệm xem lịch theo ngày và doanh thu tháng." },
    { name: "Phòng khám nha khoa", request: "Lễ tân quản lý bệnh nhân và đặt lịch hẹn với bác sĩ. Màn hình chính là lịch hẹn hôm nay." },
    { name: "Quán cà phê", request: "Khách quét mã QR ở bàn để gọi món, quầy pha chế thấy đơn ngay, thu ngân tính tiền và in hoá đơn." },
    { name: "Lớp học thêm", request: "Quản lý học sinh và lớp, điểm danh từng buổi, học phí hàng tháng và danh sách phụ huynh chưa đóng tiền." },
    { name: "Nhà trọ", request: "Quản lý phòng trọ, người thuê và hợp đồng. Mỗi tháng nhập số điện nước, tự tính tiền và in phiếu thu." },
    { name: "Kho hàng", request: "Nhập kho, xuất kho, tồn kho theo từng sản phẩm, và cảnh báo khi hàng sắp hết." }
  ]

  def suggestions
    SUGGESTIONS
  end

  # A colored tile with the app's initial, until there is a picture of it.
  def monogram(project)
    hue = project.name.to_s.sum % 360
    tag.div(project.name.to_s.strip.first.to_s.upcase, class: "monogram", style: "--hue: #{hue}", "aria-hidden": true)
  end

  # Where a new app is before its first build (Describe, Plan, Build) and what to do next.
  def blank_preview_status(project)
    if project.working?
      [ 1, "The agent is reading your request and working out a plan. Nothing changes in the app yet." ]
    elsif project.latest_proposal
      [ 1, "The plan is ready. Read it in the chat, then press “#{project.approval_message}” and it gets built here." ]
    elsif project.open_reply&.data&.dig("questions").present?
      [ 1, "The agent has a few questions. Answer them in the chat and it carries on." ]
    elsif project.failed?
      [ 0, "The last step didn't finish. Tell the agent in the chat what to try." ]
    else
      [ 0, "Describe the app you want in the chat. The agent plans it with you, then builds it here." ]
    end
  end

  def project_subtitle(project)
    if live = project.live_deployment
      "Live at #{project.publish_host}"
    else
      "Edited #{time_ago_in_words(project.updated_at)} ago"
    end
  end
end
