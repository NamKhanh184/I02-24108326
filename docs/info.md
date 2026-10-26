## Thiết kế này làm gì

Thiết kế I02 nhận một số nguyên không dấu 8 bit và tính căn bậc hai nguyên của nó. Với mỗi giá trị đầu vào `x`, mạch xuất kết quả 4 bit `root` thỏa mãn `root^2 <= x < (root+1)^2`. Thiết kế là mạch tuần tự đồng bộ theo cạnh lên của clock.

## Cách hoạt động

Mạch đọc `x` khi cổng `start` được đặt mức cao, rồi thực hiện thuật toán so sánh và trừ trong 4 chu kỳ. Mỗi chu kỳ xử lý một cặp bit của đầu vào, cập nhật phần dư và xây dựng `root` từng bit. Máy trạng thái có ba trạng thái: nghỉ, lặp và hoàn tất. Cổng `busy` báo thiết kế đang xử lý; cổng `done` xung một chu kỳ khi kết quả sẵn sàng.

## Cách kiểm thử

Testbench kiểm các giá trị `0`, `1`, `2`, `3`, `4`, các giá trị giữa, các số chính phương, và biên `255`. Các ca biên đặc biệt gồm `0`, `255`, cặp số liền kề quanh căn chính xác và giá trị lớn nhất có thể. Mỗi ca chờ xung `done` rồi đối chiếu `root` với giá trị mong đợi.

## Ánh xạ chân

| Chân | Tín hiệu | Ý nghĩa |
|---|---|---|
| `ui_in[7:0]` | `x[7:0]` | Số đầu vào 8 bit |
| `uio_in[0]` | `start` | Bắt đầu phép tính |
| `uo_out[3:0]` | `root[3:0]` | Căn bậc hai nguyên |
| `uo_out[5]` | `busy` | Mạch đang xử lý |
| `uo_out[4]` | `done` | Kết quả đã hoàn tất |
| `uio_out[7:0]` | - | Không sử dụng |

## Giới hạn

Thiết kế chỉ hỗ trợ đầu vào 8 bit không dấu và đầu ra 4 bit. Không báo tràn hay phần dư ngoài giao diện; kết quả dừng ở phần nguyên của căn. Các kết quả mô phỏng và tổng hợp chưa chứng minh sign-off, tape-out, hay kiểm tra silicon.
