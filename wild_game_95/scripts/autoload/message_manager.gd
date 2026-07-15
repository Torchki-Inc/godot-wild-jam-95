extends Node

signal message_displayed(text: String)

var queue: Array[String] = []
var is_displaying: bool = false

func show_message(key: String, params: Dictionary):
    var text: String = Message.TEXT.get(key, key)
    for param_key in params:
        text = text.replace("{%s}" % param_key, str(params[param_key]))
    queue.append(text)
    if not is_displaying:
        process_message()


func process_message():
    if queue.is_empty():
        is_displaying = false
        return
    is_displaying = true
    var text: String = queue.pop_front()
    message_displayed.emit(text)
