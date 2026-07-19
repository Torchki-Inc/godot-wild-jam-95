extends Node

signal message_displayed(text: String)
signal queue_finished

var queue: Array[String] = []
var is_displaying: bool = false

const MAX_WORDS_PER_KEY_MESSAGE := 20
const MAX_WORDS_PER_CUSTOM_MESSAGE := 25

func show_message(key: String, params: Dictionary = {}):
	var text: String = Message.TEXT.get(key, key)
	for param_key in params:
		text = text.replace("{%s}" % param_key, str(params[param_key]))
	_enqueue_split(text, MAX_WORDS_PER_KEY_MESSAGE)
	if not is_displaying:
		process_message()

func show_custom_message(text: String):
	print("custom message: %s" % text)
	_enqueue_split(text, MAX_WORDS_PER_CUSTOM_MESSAGE)

func _enqueue_split(text: String, max_words: int) -> void:
	var words: PackedStringArray = text.split(" ")
	if words.size() <= max_words:
		queue.append(text)
	else:
		var chunks: PackedStringArray = []
		for word in words:
			chunks.append(word)
			if chunks.size() >= max_words:
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
