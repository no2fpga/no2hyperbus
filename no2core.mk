CORE := no2hyperbus

DEPS_no2hyperbus := no2ice40

RTL_SRCS_no2hyperbus := $(addprefix rtl/, \
	hbus_dline.v \
	hbus_phy_ice40.v \
	hbus_memctrl.v \
)

TESTBENCHES_no2hyperbus := \
	hbus_memctrl_tb \
	$(NULL)

include $(NO2BUILD_DIR)/core-magic.mk
