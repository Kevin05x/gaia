extends GutTest
## Qué ajuste gráfico se elige solo en el navegador según la tarjeta (scenes/b/graficos.gd › es_gpu_dedicada).


func test_las_tarjetas_dedicadas_se_reconocen() -> void:
	for nombre in ["ANGLE (NVIDIA, NVIDIA GeForce RTX 3060 Laptop GPU Direct3D11 vs_5_0 ps_5_0, D3D11)",
			"ANGLE (AMD, AMD Radeon RX 6600 Direct3D11 vs_5_0 ps_5_0, D3D11)", "Apple M2", "ANGLE (NVIDIA, NVIDIA GeForce GTX 1650 Direct3D11)"]:
		assert_true(Graficos.es_gpu_dedicada(nombre), nombre)


func test_las_integradas_y_lo_desconocido_no_cuentan_como_dedicadas() -> void:
	for nombre in ["ANGLE (Intel, Intel(R) UHD Graphics (0x000046A3) Direct3D11 vs_5_0 ps_5_0, D3D11)", "Intel(R) Iris(R) Xe Graphics",
			"ANGLE (AMD, AMD Radeon(TM) Graphics Direct3D11)", "Google SwiftShader", "llvmpipe (LLVM 15.0.7, 256 bits)", "", "WebKit WebGL"]:
		assert_false(Graficos.es_gpu_dedicada(nombre), nombre)


func test_en_el_escritorio_el_ajuste_de_fabrica_sigue_siendo_alta() -> void:
	assert_eq(Graficos.defecto(), Graficos.DEFECTO)
