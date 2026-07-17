extends Node

signal message_displayed(text: String)
signal queue_finished

const MAX_WORDS_PER_MESSAGE := 12

var queue: Array[String] = []
var is_displaying: bool = false

func show_message(key: String, params: Dictionary = {}):
	var text: String = Message.TEXT.get(key, key)
	for param_key in params:
		text = text.replace("{%s}" % param_key, str(params[param_key]))
	_enqueue_split(text)
	if not is_displaying:
		process_message()

func show_custom_message(text: String):
	print("custom message: %s" % text)
	_enqueue_split(text)

func _enqueue_split(text: String) -> void:
	var words: PackedStringArray = text.split(" ")
	if words.size() <= MAX_WORDS_PER_MESSAGE:
		queue.append(text)
	else:
		var chunks: PackedStringArray = []
		for word in words:
			chunks.append(word)
			if chunks.size() >= MAX_WORDS_PER_MESSAGE:
				queue.append(" ".join(chunks))
				chunks.clear()
		if not chunks.is_empty():
			queue.append(" ".join(chunks))
	if not is_displaying:
		process_message()

func process_message():
	if queue.is_empty():
		is_displaying = false
		queue_finished.emit()
		return
	is_displaying = true
	var text: String = queue.pop_front()
	message_displayed.emit(text)

func advance_message():
	process_message()
