extends Resource
class_name PetBehavior

## Base class cho tất cả behavior của Pet.
## Extend class này để thêm hành vi mới (scratch post, toy, v.v.) mà không sửa Pet.gd.
## Sau đó thêm instance vào mảng extra_behaviors trên Pet node trong Inspector.

@export var priority : float = 10.0  # cao hơn → được đánh giá trước
@export var enabled  : bool  = true

## Trả về true nếu behavior này nên kích hoạt ngay bây giờ.
## Gọi mỗi frame khi pet ở trạng thái idle / không bận.
func should_activate(_pet: Pet) -> bool:
	return false

## Thực thi behavior: thiết lập navigation, anim, callbacks.
## Chỉ được gọi khi should_activate() trả về true.
func activate(_pet: Pet) -> void:
	pass
