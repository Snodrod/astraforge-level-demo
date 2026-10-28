// Ветер для 2D-спрайтов (деревья, трава, кусты): верх сдвигается сильнее низа.
// Точка узла стоит на земле (основание спрайта), поэтому «высота» — это -VERTEX.y.
// Сдвиг округляется до целых пикселей, чтобы пиксель-арт не «плыл».
shader_type canvas_item;

uniform float amplitude = 2.0;      // пикселей у верхушки
uniform float speed = 1.8;
uniform float sprite_height = 64.0; // высота спрайта в пикселях
uniform float stiffness = 2.0;      // чем больше, тем твёрже низ

void vertex() {
	// фаза зависит от места экземпляра на карте
	float phase = MODEL_MATRIX[3].x * 0.09 + MODEL_MATRIX[3].y * 0.05;
	float top = pow(clamp(-VERTEX.y / sprite_height, 0.0, 1.0), stiffness);   // 0 внизу, 1 на макушке
	float gust = sin(TIME * speed + phase) + 0.35 * sin(TIME * speed * 2.4 + phase * 1.6);
	VERTEX.x += floor(gust * amplitude * top + 0.5);
}
