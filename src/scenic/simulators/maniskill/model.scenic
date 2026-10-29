"""Scenic world model for robotic manipulation scenarios in ManiSkill.

Global Parameters:
    render (bool): Whether to render the simulation in a window. If True, it will open
        a window and display the simulation. If False (default), the simulation runs headless.
    stride (int): Number of simulation steps between action updates. Default is 1.
    shader_pack (str): ManiSkill shader pack to use for cameras. Default is "default".
        Other ManiSkill shader packs such as "minimal" or "rt" can also be used.
"""

from scenic.core.vectors import Vector
import numpy as np
from scipy.spatial.transform import Rotation
from mani_skill.utils.building import actors
from transform3d.euler import euler2quat

try:
    from scenic.simulators.maniskill.simulator import ManiSkillSimulator
except ModuleNotFoundError:
    # for convenience when testing without the mani_skill package
    from scenic.core.simulators import SimulatorInterfaceWarning
    import warnings
    warnings.warn('The "mani-skill" package is not installed; '
                  'will not be able to run dynamic simulations',
                  SimulatorInterfaceWarning)

    def ManiSkillSimulator(*args, **kwargs):
        """Dummy simulator to allow compilation without the 'mani-skill' package.

        :meta private:
        """
        raise RuntimeError('the "mani-skill" package is required to run simulations '
                           'from this scenario')

param render = False
param stride = 1
param shader_pack = "default"

simulator ManiSkillSimulator(
    render=bool(globalParameters.render),
    stride=int(globalParameters.stride),
    shader_pack=globalParameters.shader_pack,
)

class ManiskillObject(Object):
    """Base class for ManiSkill objects.

    Properties:
        visualFilename (str or None): Path to a visual mesh file (e.g., .glb, .obj, .usdz).
        visualScale (tuple): Scale factor for the visual mesh as (x, y, z).
        visualOffset (tuple): Offset for the visual mesh as (x, y, z) to match visual and collision meshes.
        kinematic (bool): If True, the object is kinematic (fixed in place).
    """
    name: "maniskill_object"
    visualFilename: None
    visualScale: (1, 1, 1)
    visualOffset: (0, 0, 0)
    width: 1
    length: 1
    height: 1
    color: [0.8, 0.8, 0.8, 1.0]
    kinematic: False
    z_offset : 0
    scale : 1
    # is_actor : False
    actor_func : None

    def scenicToSimPose(self, position, roll, pitch, yaw):
        # return position, Vector(roll, pitch, yaw+1.57)
        # return position, Vector(roll, pitch+1.57, yaw)
        return position, Vector(roll, pitch, yaw)

    def simToScenicPose(self, position, roll, pitch, yaw):
        # return position, Vector(roll, pitch, yaw-1.57)
        # return position, Vector(roll+1.57, pitch, yaw)
        return position, Vector(roll, pitch, yaw)

class Cube(ManiskillObject):
    # is_actor: True
    actor_func: self.build_cube
    def build_cube(self, mani_scene):
        actors.build_cube(
            mani_scene,
            half_size = self.width/2,
            color=self.color,
            name=self.name,
            initial_pose=sapien.Pose(p=self.position, q=euler2quat(self.roll, self.pitch, self.yaw)),
        )



class Ground(ManiskillObject):
    """The default ground plane from ManiSkill.

    This creates a large flat ground plane using ManiSkill's built-in ground builder.
    The ground is always kinematic (fixed in place).
    """
    name: "ground"
    shape: BoxShape()
    width: 100
    length: 100
    height: 0.001
    position: (0, 0, -0.0005)
    kinematic: True
    visualFilename: None
    isSimpleGround: True  # Specify to ManiSkill that this is the ground plane


class Robot(Object):
    """Robot object (Panda arm by default).

    This class represents a robot in the scene. The robot is not physically generated
    in the scene (skipGeneration=True) but is used to configure the robot's initial state.

    Properties:
        uuid (str): Robot type identifier. Default is "panda" for the Franka Emika Panda arm.
        jointAngles (list): Initial joint angles for the robot. If empty, uses a default configuration.
    """
    # should make position and orientation dynamic, or are they already so? and are they cached?
    # stupid...parentOrientation buddy!
    # parentOrientation : self.baseFrame.orientation # might not work too well
    # position:    # Make scenic ignore it for collision checking for now perhaps should make this unassignable?
    # user sets the position and orientation of this baseFrame.
    # in this case, can treat this baseFrame as x-forward
    # baseFrame: new OrientedPoint() 
    
    name: "actor"
    uuid: "panda"
    jointAngles: []
    skipGeneration: True  # Don't generate this object in the scene
    def scenicToSimPose(self, position, roll, pitch, yaw):
        return position, Vector(roll, pitch, yaw)

    def simToScenicPose(self, position, roll, pitch, yaw):
        return position, Vector(roll, pitch, yaw)
    # orientation: self.baseFrame.orientation + self._baseToScenicRot
    # def scenicToSimPose(self, position, roll, pitch, yaw):
        # return position, Vector(roll, pitch, yaw)

    # def simToScenicPose(self, position, roll, pitch, yaw):
        # return position, Vector(roll, pitch, yaw)
    
    # orientation of the base, represented as the scenic frame
    # _baseToScenicRotMat: Rotation.from_matrix([[0, 1, 0],
                                             # [-1, 0, 0],
                                             # [0, 0, 1]])
    # _scenicToBaseRotMat: np.linalg.inv(self.baseToScenicRotMat.as_matrix)
    # _baseToScenicRot: Rotation.from_euler('xyz', [0,0,-90], degrees=True) # extrinsic euler angle
    # _scenicToBaseRot: Rotation.from_euler(self._baseToScenicRot.as_matrix())

    # _baseToScenicOffset: (0,0,0)
    # _scenicToBaseOffset: -self._baseToScenicOffset

    # def baseToScenicPosition(self):
        # return self.baseFrame.position + self._baseToScenicOffset

    # def scenicToBasePosition(self):
        # return self.position + self.scenicToBaseOffset

    # def baseToScenicOrientation(self):
        # # really coding the orientation here
        # # write the scipy rotation matrix
        # # multiply it by the orientation of the baseFrame
        # # won't change for a stationary robot,
        # # but good infrastructure for a mobile robot
        # transformation = 
    
    # def scenicToBaseOrientation(self):
        # pass

    # def scenicToSimCoord(self):
        # return self.position, (self.roll, self.pitch, self.yaw + 1.57)
    # def simToScenicCoord(self):
        # return self.position, (self.roll, self.pitch, self.yaw - 1.57)
    
# class Camera(OrientedPoint):
class Camera(Object):
    """Camera configuration for the scene.

    Cameras are not physical objects but define viewpoints for rendering and observation.

    Properties:
        img_width (int): Image width in pixels. Default is 640.
        img_height (int): Image height in pixels. Default is 480.
        fov (float): Field of view in radians. Default is 1.0.
        near (float): Near clipping plane distance. Default is 0.01.
        far (float): Far clipping plane distance. Default is 100.0.
        shader_pack (str): Shader pack to use for rendering. Defaults to the global
            ``shader_pack`` parameter, which is "default" unless overridden.
    """
    name: "camera"
    obj_type: "camera"
    img_width: 640
    img_height: 480
    fov: 1.0
    near: 0.01
    far: 100.0
    shader_pack: globalParameters.shader_pack
    skipGeneration: True  # Don't generate this as a physical object
    targetPos: (0.0, 0.0, 0.0)
    width: 1e-9
    length: 1e-9
    height: 1e-9
